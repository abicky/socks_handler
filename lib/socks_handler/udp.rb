# frozen_string_literal: true
require "socks_handler"
require "socks_handler/command"
require "socks_handler/udpsocket"

module SocksHandler
  class UDP
    class << self
      include SocksHandler

      # Associates a TCP socket with a UDP connection
      #
      # @param socket [Socket, TCPSocket] a socket that has connected to a socks server
      # @param bind_host [String] host for UDPSocket#bind
      # @param bind_port [Integer, String] port for UDPSocket#bind
      # @param username [String, nil]
      # @param password [String, nil]
      # @return [SocksHandler::UDPSocket]
      #
      # @example
      #   tcp_socket = TCPSocket.new("127.0.0.1", 1080) # or Socket.tcp("127.0.0.1", 1080)
      #   udp_socket = SocksHandler::UDP.associate_udp(tcp_socket, "0.0.0.0", 0)
      #
      #   "echo" is a UDP echo server that only the socks server can access
      #   udp_socket.send("hello", 0, "echo", 7)
      #   puts udp_socket.gets #=> hello
      def associate_udp(socket, bind_host, bind_port, username = nil, password = nil)
        negotiate(socket, username, password)
        address, port = send_details(socket,  Command::UDP_ASSOCIATE, bind_host, bind_port)
        SocksHandler::UDPSocket.new.tap do |s|
          # Use peeraddr instead of address
          # because we might not be able to access the address directly
          s.bind(bind_host, bind_port)
          s.connect_socks_server(socket.peeraddr[3], port)
        end
      end
    end
  end
end
