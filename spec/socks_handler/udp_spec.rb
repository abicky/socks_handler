# frozen_string_literal: true
require "net/http"

RSpec.describe SocksHandler::UDP do
  it "can assess the echo server" do
    tcp_socket = TCPSocket.new("127.0.0.1", 1080) # or Socket.tcp("127.0.0.1", 1080)
    udp_socket = SocksHandler::UDP.associate_udp(tcp_socket, "0.0.0.0", 0)
    udp_socket.send("hello", 0, "echo", 7)
    expect(udp_socket.recv(100)).to eq "hello"

    udp_socket.send("world", 0, "echo", 7)
    IO::select([udp_socket], nil, nil, 5)
    msg, _ = udp_socket.recvfrom_nonblock(100)
    expect(msg).to eq "world"
  end
end
