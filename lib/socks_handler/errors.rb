# frozen_string_literal: true

class SocksHandler
  class UnsupportedProtocol < StandardError; end

  class NoAcceptableMethods < StandardError; end

  class AuthenticationFailure < StandardError; end

  class RelayRequestFailure < StandardError
    def initialize(code)
      case code
      when 0x01
        super("general SOCKS server failure")
      when 0x02
        super("connection not allowed by ruleset")
      when 0x03
        super("Network unreachable")
      when 0x04
        super("Host unreachable")
      when 0x05
        super("Connection refused")
      when 0x06
        super("TTL expired")
      when 0x07
        super("Command not supported")
      when 0x08
        super("Address type not supported")
      else
        super("Unknown error")
      end
    end
  end
end
