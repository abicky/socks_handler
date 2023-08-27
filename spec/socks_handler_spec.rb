# frozen_string_literal: true
require "net/http"

RSpec.describe SocksHandler do
  def send_head_request(socket_build_method, host, port)
    socket = socket_build_method.call(host, port)
    socket.write(<<~REQUEST.gsub("\n", "\r\n"))
      HEAD / HTTP/1.1
      Host: #{host}

    REQUEST
    socket.gets.chomp
  end

  after do
    SocksHandler.desocksify
  end

  describe ".fine_rule" do
    before do
      SocksHandler.socksify([rule1, rule2])
    end

    let(:rule1) do
      SocksHandler::DirectAccessRule.new(host_patterns: %w[127.0.0.1 ::1])
    end
    let(:rule2) do
      SocksHandler::ProxyAccessRule.new(host_patterns: ["192.168.0.2", /(?:\A|\.)example\.com\z/], socks_server: "127.0.0.1:1080")
    end

    it "returns the first rule that matches with the patterns" do
      expect(described_class.find_rule("127.0.0.1")).to be rule1
      expect(described_class.find_rule("::1")).to be rule1
      expect(described_class.find_rule("192.168.0.2")).to be rule2
      expect(described_class.find_rule("example.com")).to be rule2
      expect(described_class.find_rule("test.example.com")).to be rule2
      expect(described_class.find_rule("testexample.com")).to be_nil
    end
  end

  describe ".socksify" do
    before do
      SocksHandler.socksify(rules)
    end

    context "with authentication method 'none'" do
      let(:rules) do
        [
          SocksHandler::ProxyAccessRule.new(host_patterns: ["nginx"], socks_server: "127.0.0.1:1080"),
        ]
      end

      it "can access nginx" do
        [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
          expect(send_head_request(method, "nginx", 80)).to eq "HTTP/1.1 200 OK"
        end

        Net::HTTP.start("nginx", 80) do |http|
          expect(http.head("/").message).to eq "OK"
        end
      end
    end

    context "with authentication method 'username/password'" do
      let(:rules) do
        [
          SocksHandler::ProxyAccessRule.new(
            host_patterns: ["nginx"],
            socks_server: "127.0.0.1:1081",
            username: "user",
            password: password,
          ),
        ]
      end

      context "with correct username/password" do
        let(:password) { "pass" }

        it "can access nginx" do
          [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
            expect(send_head_request(method, "nginx", 80)).to eq "HTTP/1.1 200 OK"
          end

          Net::HTTP.start("nginx", 80) do |http|
            expect(http.head("/").message).to eq "OK"
          end
        end
      end

      context "with wrong username/password" do
        let(:password) { "wrong_pass" }

        it "raises an error" do
          [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
            expect {
              send_head_request(method, "nginx", 80)
            }.to raise_error(SocksHandler::AuthenticationFailure)
          end

          expect {
            Net::HTTP.start("nginx", 80) {}
          }.to raise_error(SocksHandler::AuthenticationFailure)
        end
      end
    end

    context "with direct access" do
      let(:rules) do
        [
          SocksHandler::DirectAccessRule.new(host_patterns: ["nginx"]),
        ]
      end

      it "cannot resolve the hostname" do
        [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
          expect {
            send_head_request(TCPSocket.method(:new), "nginx", 80)
          }.to raise_error(SocketError, /getaddrinfo/)
        end

        expect {
          Net::HTTP.start("nginx", 80) {}
        }.to raise_error(SocketError, /getaddrinfo/)
      end
    end

    context "with service name" do
      let(:rules) do
        [
          SocksHandler::ProxyAccessRule.new(host_patterns: ["nginx"], socks_server: "127.0.0.1:1080"),
        ]
      end

      it "can access nginx" do
        [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
          expect(send_head_request(method, "nginx", "http")).to eq "HTTP/1.1 200 OK"
        end
      end
    end

    context "with IPv4 address" do
      let(:rules) do
        [
          SocksHandler::ProxyAccessRule.new(host_patterns: [//], socks_server: "127.0.0.1:1080"),
        ]
      end

      it "can access nginx" do
        host = `docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker compose ps -q nginx)`.chomp
        [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
          expect(send_head_request(method, host, "http")).to eq "HTTP/1.1 200 OK"
        end
      end
    end

    context "with IPv6 address" do
      let(:rules) do
        [
          SocksHandler::ProxyAccessRule.new(host_patterns: [//], socks_server: "127.0.0.1:1080"),
        ]
      end

      it "can access nginx" do
        host = `docker inspect -f '{{range.NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $(docker compose ps -q nginx)`.chomp
        [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
          expect(send_head_request(method, host, "http")).to eq "HTTP/1.1 200 OK"
        end
      end
    end
  end

  describe ".desocksify" do
    it do
      rules = [
        SocksHandler::ProxyAccessRule.new(host_patterns: [//], socks_server: "127.0.0.1:1080"),
      ]
      SocksHandler.socksify(rules)
      [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
        expect(send_head_request(method, "nginx", "http")).to eq "HTTP/1.1 200 OK"
      end

      SocksHandler.desocksify
      [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
        expect {
          Net::HTTP.start("nginx", 80) {}
        }.to raise_error(SocketError, /getaddrinfo/)
      end

      SocksHandler.socksify(rules)
      [TCPSocket.method(:new), Socket.method(:tcp)].each do |method|
        expect(send_head_request(method, "nginx", "http")).to eq "HTTP/1.1 200 OK"
      end
    end
  end
end
