# frozen_string_literal: true

class SocksHandler
  # @!attribute [r] host
  #   @return [String, nil]
  # @!attribute [r] port
  #   @return [Integer, nil]
  # @!attribute [r] username
  #   @return [String, nil]
  # @!attribute [r] password
  #   @return [String, nil]
  # @!attribute [r] host_patterns
  #   @return [Array<String, Regexp>]
  class Rule
    attr_reader :host, :port, :username, :password, :host_patterns

    # @return [Rule]
    def self.new(**kwargs)
      raise "Rule is an abstract class" if self == Rule
      super
    end

    # @param host_patterns [Array<String, Regexp>]
    # @param host [String, nil]
    # @param port [Integer, nil]
    # @param username [String, nil]
    # @param password [String, nil]
    def initialize(host_patterns:, host: nil, port: nil, username: nil, password: nil)
      @host = host
      @port = port
      @username = username
      @password = password
      self.host_patterns = host_patterns
    end

    # @return [Boolean]
    def direct
      raise NotImplementedError
    end

    # @param value [Array<String, Regexp>]
    # @return [Array<String, Regexp>]
    def host_patterns=(value)
      raise ArgumentError, "host_patterns is not an array" unless value.is_a?(Array)
      @host_patterns = value.frozen? ? value : value.dup.freeze
      @remote_host_pattern_regex = Regexp.union(convert_regexps(value))
      value
    end

    # @param remote_host [String]
    # @return [Boolean]
    def match?(remote_host)
      @remote_host_pattern_regex.match?(remote_host)
    end

    private

    # @param value [Array<String, Regexp>]
    # @return [Array<Regexp>]
    def convert_regexps(value)
      value.map do |v|
        v.is_a?(Regexp) ? v : Regexp.new("\\A#{Regexp.escape(v)}\\z")
      end
    end
  end
end
