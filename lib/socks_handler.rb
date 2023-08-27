# frozen_string_literal: true
require "ipaddr"
require "socket"

require "socks_handler/address_type"
require "socks_handler/authentication_method"
require "socks_handler/command"
require "socks_handler/direct_access_rule"
require "socks_handler/errors"
require "socks_handler/proxy_access_rule"
require "socks_handler/socket_socksify"
require "socks_handler/tcpsocket_socksify"
require "socks_handler/username_password_authenticator"
require "socks_handler/version"

# An implementation of https://www.ietf.org/rfc/rfc1928.txt
class SocksHandler
  # @return [Integer]
  PROTOCOL_VERSION = 0x05
  class << self
    # Socksifies all TCP connections created by TCPSocket.new or Socket.tcp
    #
    # @param rules [Array<DirectAccessRule, ProxyAccessRule>] socksify a
    #   socket according to the first rule whose remote host patterns match
    #   the remote host
    # @return [nil]
    #
    # @example
    #   SocksHandler.socksify([
    #     # Access 127.0.0.1, ::1 or hosts that end in ".local" directly
    #     SocksHandler::DirectAccessRule.new(remote_host_patterns: %w[127.0.0.1 ::1] + [/\.local\z/]),
    #
    #     # Access hosts that end in ".ap-northeast-1.compute.internal" through 127.0.0.1:1080
    #     SocksHandler::ProxyAccessRule.new(
    #       remote_host_patterns: [/\.ap-northeast-1\.compute\.internal\z/],
    #       socks_server: "127.0.0.1:1080",
    #     ),
    #
    #     # Access hosts that end in ".ec2.internal" through 127.0.0.1:1081
    #     SocksHandler::ProxyAccessRule.new(
    #       remote_host_patterns: [/\.ec2\.internal\z/],
    #       socks_server: "127.0.0.1:1081",
    #     ),
    #
    #     # Access others hosts through 127.0.0.1:1082 with username/password auth
    #     SocksHandler::ProxyAccessRule.new(
    #       remote_host_patterns: [//],
    #       socks_server: "127.0.0.1:1082",
    #       username: "user",
    #       password: ENV["SOCKS_SERVER_PASSWORD"],
    #     ),
    #   ])
    def socksify(rules)
      @rules = rules

      unless ::TCPSocket.ancestors.include?(SocksHandler::TCPSocketSocksify)
        TCPSocket.prepend(SocksHandler::TCPSocketSocksify)
      end

      unless Socket.singleton_class.ancestors.include?(SocksHandler::SocketSocksify)
        Socket.singleton_class.prepend(SocksHandler::SocketSocksify)
      end

      nil
    end

    # @return [nil]
    def desocksify
      @rules = []
      nil
    end

    # @param host [String] a domain name or IP address of a remote host
    # @return [DirectAccessRule, ProxyAccessRule, nil]
    def find_rule(host)
      rules.find { |r| r.match?(host) }
    end

    # @param socket [Socket, TCPSocket] a socket that has connected to a socks server
    # @param remote_host [String]
    # @param remote_port [Integer, String] a port number or service name such as "http"
    # @param username [String, nil]
    # @param password [String, nil]
    # @return [nil]
    def establish_connection(socket, remote_host, remote_port, username = nil, password = nil)
      negotiate(socket, username, password)
      send_connect_request(socket, remote_host, remote_port.is_a?(String) ? Socket.getservbyname(remote_port) : remote_port)
      nil
    end

    private

    # @return [Array<DirectAccessRule, ProxyAccessRule>]
    def rules
      @rules ||= []
    end

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
    # @param remote_host [String]
    # @param remote_port [Integer]
    # @return [nil]
    def send_connect_request(socket, remote_host, remote_port)
      begin
        ipaddr = IPAddr.new(remote_host)
      rescue IPAddr::InvalidAddressError
        # Just ignore the error because remote_host must be a domain name
      end

      request = [PROTOCOL_VERSION, Command::CONNECT, 0x00].pack("C*")
      case
      when ipaddr.nil?
        request << [AddressType::DOMAINNAME, remote_host.size, remote_host].pack("CCa*")
      when ipaddr.ipv4?
        request << [AddressType::IPV4, ipaddr.hton].pack("Ca*")
      when ipaddr.ipv6?
        request << [AddressType::IPV6, ipaddr.hton].pack("Ca*")
      else
        raise "Unknown type of IPAddr: #{ipaddr.inspect}"
      end
      request << [remote_port].pack("n")
      socket.write(request)

      _, rep, _, atyp = socket.recv(4).unpack("C*")
      raise RelayRequestFailure.new(rep) if rep != 0x00

      case atyp
      when AddressType::IPV4
        bound_address = IPAddr.ntop(socket.recv(4))
      when AddressType::DOMAINNAME
        len = socket.recv(1).unpack("C").first
        bound_address = socket.recv(len).unpack("a*").first
      when AddressType::IPV6
        bound_address = IPAddr.ntop(socket.recv(16))
      else
        raise "Unknown atyp #{atyp}"
      end
      bound_port = socket.recv(2).unpack("n").first

      [bound_address, bound_port]
    end
  end
end
