# frozen_string_literal: true
require "socks_handler"
require "socks_handler/command"
require "socks_handler/direct_access_rule"
require "socks_handler/proxy_access_rule"
require "socks_handler/socket_socksify"
require "socks_handler/tcpsocket_socksify"

module SocksHandler
  class TCP
    class << self
      include SocksHandler

      # Socksifies all TCP connections created by TCPSocket.new or Socket.tcp
      #
      # @param rules [Array<DirectAccessRule, ProxyAccessRule>] socksify a
      #   socket according to the first rule whose remote host patterns match
      #   the remote host
      # @return [nil]
      #
      # @example
      #   SocksHandler::TCP.socksify([
      #     # Access 127.0.0.1, ::1 or hosts that end in ".local" directly
      #     SocksHandler::DirectAccessRule.new(host_patterns: %w[127.0.0.1 ::1] + [/\.local\z/]),
      #
      #     # Access hosts that end in ".ap-northeast-1.compute.internal" through 127.0.0.1:1080
      #     SocksHandler::ProxyAccessRule.new(
      #       host_patterns: [/\.ap-northeast-1\.compute\.internal\z/],
      #       socks_server: "127.0.0.1:1080",
      #     ),
      #
      #     # Access hosts that end in ".ec2.internal" through 127.0.0.1:1081
      #     SocksHandler::ProxyAccessRule.new(
      #       host_patterns: [/\.ec2\.internal\z/],
      #       socks_server: "127.0.0.1:1081",
      #     ),
      #
      #     # Access others hosts through 127.0.0.1:1082 with username/password auth
      #     SocksHandler::ProxyAccessRule.new(
      #       host_patterns: [//],
      #       socks_server: "127.0.0.1:1082",
      #       username: "user",
      #       password: ENV["SOCKS_SERVER_PASSWORD"],
      #     ),
      #   ])
      def socksify(rules)
        @rules = rules

        unless TCPSocket.ancestors.include?(SocksHandler::TCPSocketSocksify)
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

      # Connects a host through a socks server
      #
      # @param socket [Socket, TCPSocket] a socket that has connected to a socks server
      # @param remote_host [String]
      # @param remote_port [Integer, String] a port number or service name such as "http"
      # @param username [String, nil]
      # @param password [String, nil]
      # @return [nil]
      #
      # @example
      #   socket = TCPSocket.new("127.0.0.1", 1080) # or Socket.tcp("127.0.0.1", 1080)
      #   # "nginx" is an HTTP server only the socks server can access
      #   SocksHandler::TCP.establish_connection(socket, "nginx", 80)
      #
      #   socket.write(<<~REQUEST.gsub("\n", "\r\n"))
      #     HEAD / HTTP/1.1
      #     Host: nginx
      #
      #   REQUEST
      #   puts socket.gets #=> HTTP/1.1 200 OK
      def establish_connection(socket, remote_host, remote_port, username = nil, password = nil)
        negotiate(socket, username, password)
        send_details(socket,  Command::CONNECT, remote_host, remote_port)
        nil
      end

      private

      # @return [Array<DirectAccessRule, ProxyAccessRule>]
      def rules
        @rules ||= []
      end
    end
  end
end
