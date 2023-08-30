# frozen_string_literal: true

module SocksHandler
  module Command
    # @return [Integer]
    CONNECT = 0x01
    # @return [Integer]
    BIND = 0x02 # Not supported yet
    # @return [Integer]
    UDP_ASSOCIATE = 0x03
  end
end
