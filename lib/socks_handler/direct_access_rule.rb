# frozen_string_literal: true
require "socks_handler/rule"

class SocksHandler
  class DirectAccessRule < Rule
    # @param remote_host_patterns [Array<String, Regexp>]
    def initialize(remote_host_patterns:)
      super(remote_host_patterns: remote_host_patterns)
    end

    # @return [true]
    def direct
      true
    end
  end
end
