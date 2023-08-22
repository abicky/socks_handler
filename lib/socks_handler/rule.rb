# frozen_string_literal: true

class SocksHandler
  class Rule
    attr_reader :host, :port, :username, :password, :remote_host_patterns, :remote_host_pattern_regex

    def self.new(**kwargs)
      raise "Rule is an abstract class" if self == Rule
      super
    end

    def initialize(remote_host_patterns:, host: nil, port: nil, username: nil, password: nil)
      @host = host
      @port = port
      @username = username
      @password = password
      self.remote_host_patterns = remote_host_patterns
    end

    def direct
      raise NotImplementedError
    end

    def remote_host_patterns=(value)
      raise ArgumentError, "remote_host_patterns is not an array" unless value.is_a?(Array)
      @remote_host_patterns = value.frozen? ? value : value.dup.freeze
      @remote_host_pattern_regex = Regexp.union(convert_regexps(value))
    end

    private

    def convert_regexps(value)
      value.map do |v|
        v.is_a?(Regexp) ? v : Regexp.new("\\A#{Regexp.escape(v)}\\z")
      end
    end
  end
end
