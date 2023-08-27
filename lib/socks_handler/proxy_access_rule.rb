# frozen_string_literal: true
require "socks_handler/rule"

class SocksHandler
  class ProxyAccessRule < Rule
    # @param remote_host_patterns [Array<String, Regexp>]
    # @param socks_server [String] a string in the format "<host>:<port>"
    # @param username [String, nil]
    # @param password [String, nil]
    def initialize(remote_host_patterns:, socks_server:, username: nil, password: nil)
      host, port = socks_server.split(":")
      super(remote_host_patterns: remote_host_patterns, host: host, port: port.to_i, username: username, password: password)
    end

    # @return [false]
    def direct
      false
    end
  end
end
