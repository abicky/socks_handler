# frozen_string_literal: true

module SocksHandler
  module UDPSocketSocksify
    # @param host [String]
    # @param port [Integer]
    # @return [Integer]
    def connect(host, port)
      @socks_handler_host = host
      @socks_handler_port = port

      rule = SocksHandler::UDP.find_rule(remote_host)
      return super if rule.nil? || rule.direct

      socket = TCPSocket.new(rule.host, rule.port)
      begin
        SocksHandler::UDP.associate_udp(socket, "0.0.0.0", 0, rule.username, rule.password)
      rescue
        socket.close
        raise
      end

      0
    end

    def send()
  end
end
