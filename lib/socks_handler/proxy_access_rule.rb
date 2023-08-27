# frozen_string_literal: true
require "socks_handler/rule"

class SocksHandler
  class ProxyAccessRule < Rule
    # @param host_patterns [Array<String, Regexp>]
    # @param socks_server [String] a string in the format "<host>:<port>"
    # @param username [String, nil]
    # @param password [String, nil]
    def initialize(host_patterns:, socks_server:, username: nil, password: nil)
      host, port = socks_server.split(":")
      super(host_patterns: host_patterns, host: host, port: port.to_i, username: username, password: password)
    end

    # @return [false]
    def direct
      false
    end
  end
end
