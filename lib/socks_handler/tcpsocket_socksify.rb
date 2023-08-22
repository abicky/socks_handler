# frozen_string_literal: true

class SocksHandler
  module TCPSocketSocksify
    def initialize(remote_host, remote_port, local_host = nil, local_port = nil, connect_timeout: nil)
      rule = SocksHandler.find_rule(remote_host)
      return super if rule.nil? || rule.direct

      super(rule.host, rule.port, local_host, local_port, connect_timeout: connect_timeout)
      begin
        SocksHandler.establish_connection(self, remote_host, remote_port, rule.username, rule.password)
      rescue
        close
        raise
      end
    end
  end
end
