# frozen_string_literal: true
require "ipaddr"
require "socket"

require "socks_handler/address_type"
require "socks_handler/authentication_method"
require "socks_handler/errors"
require "socks_handler/tcp"
require "socks_handler/udp"
require "socks_handler/username_password_authenticator"
require "socks_handler/version"

# An implementation of https://www.ietf.org/rfc/rfc1928.txt
# @private
module SocksHandler
  # @return [Integer]
  PROTOCOL_VERSION = 0x05

    private

    # @param socket [Socket, TCPSocket]
    # @param username [String, nil]
    # @param password [String, nil]
    # @return [nil]
    def negotiate(socket, username, password)
      case choose_auth_method(socket, username)
      when AuthenticationMethod::NONE
        # Do nothing
      when AuthenticationMethod::USERNAME_PASSWORD
        UsernamePasswordAuthenticator.new(username, password).authenticate(socket)
      else
        raise NoAcceptableMethods
      end
      nil
    end

    # @param socket [Socket, TCPSocket]
    # @param username [String, nil]
    # @return [Integer] code of authentication method
    def choose_auth_method(socket, username)
      methods = [AuthenticationMethod::NONE]
      methods << AuthenticationMethod::USERNAME_PASSWORD if username
      socket.write([PROTOCOL_VERSION, methods.size, *methods].pack("C*"))

      version, method = socket.recv(2).unpack("C2")
      if version != PROTOCOL_VERSION
        raise UnsupportedProtocol, "SOCKS5 is not supported"
      end

      method
    end

    # @param socket [Socket, TCPSocket]
    # @param command [Integer]
    # @param remote_host [String]
    # @param remote_port [Integer, String] a port number or service name such as "http"
    # @return [Array(String, Integer)] an array of [bound_address, bound_port]
    def send_details(socket, command, remote_host, remote_port)
      request = [PROTOCOL_VERSION, command, 0x00].pack("C*")
      request << build_destination_packets(remote_host, remote_port)
      socket.write(request)

      process_reply(socket)
    end

    # @param remote_host [String]
    # @param remote_port [Integer, String]
    # @return [String]
    def build_destination_packets(remote_host, remote_port)
      begin
        ipaddr = IPAddr.new(remote_host)
      rescue IPAddr::InvalidAddressError
        # Just ignore the error because remote_host must be a domain name
      end

      packets = +""
      case
      when ipaddr.nil?
        packets << [AddressType::DOMAINNAME, remote_host.size, remote_host].pack("CCa*")
      when ipaddr.ipv4?
        packets << [AddressType::IPV4, ipaddr.hton].pack("Ca*")
      when ipaddr.ipv6?
        packets << [AddressType::IPV6, ipaddr.hton].pack("Ca*")
      else
        raise "Unknown type of IPAddr: #{ipaddr.inspect}"
      end
      packets << [remote_port.is_a?(String) ? Socket.getservbyname(remote_port) : remote_port].pack("n")

      packets
    end

    # @param io [TCPSocket, Socket, StringIO]
    # @return [Array(String, Integer)] an array of [bound_address, bound_port]
    def process_reply(io)
      _, rep, _, atyp = io.read(4).unpack("C*")
      raise RelayRequestFailure.new(rep) if rep != 0x00

      case atyp
      when AddressType::IPV4
        bound_address = IPAddr.ntop(io.read(4))
      when AddressType::DOMAINNAME
        len = io.read(1).unpack("C").first
        bound_address = io.read(len).unpack("a*").first
      when AddressType::IPV6
        bound_address = IPAddr.ntop(io.read(16))
      else
        raise "Unknown atyp #{atyp}"
      end

      bound_port = io.read(2).unpack("n").first

      [bound_address, bound_port]
  end
end
