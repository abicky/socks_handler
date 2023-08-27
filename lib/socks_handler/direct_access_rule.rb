# frozen_string_literal: true
require "socks_handler/rule"

class SocksHandler
  class DirectAccessRule < Rule
    # @param host_patterns [Array<String, Regexp>]
    def initialize(host_patterns:)
      super(host_patterns: host_patterns)
    end

    # @return [true]
    def direct
      true
    end
  end
end
