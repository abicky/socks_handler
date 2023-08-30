# frozen_string_literal: true
require "socks_handler/errors"

module SocksHandler
  # An implementation of https://www.ietf.org/rfc/rfc1929.txt
  class UsernamePasswordAuthenticator
    # @return [Integer]
    SUBNEGOTIATION_VERSION = 0x01

    # @param username [String]
    # @param password [String]
    def initialize(username, password)
      raise ArgumentError, "Username is too long" if username.bytesize > 256
      raise ArgumentError, "Password is too long" if password.bytesize > 256

      @username = username
      @password = password
    end

    # @param socket [Socket, TCPSocket]
    # @return [nil]
    def authenticate(socket)
      socket.write([SUBNEGOTIATION_VERSION, @username.bytesize, @username, @password.bytesize, @password].pack("CCa*Ca*"))
      _version, status = socket.recv(2).unpack("C*")
      if status != 0x00
        raise AuthenticationFailure, "username: #{@username}, status: #{status}"
      end
      nil
    end
  end
end
