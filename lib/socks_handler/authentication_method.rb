# frozen_string_literal: true

module SocksHandler
  module AuthenticationMethod
    # @return [Integer]
    NONE = 0x00
    # @return [Integer]
    GSSAPI = 0x01 # Not supported yet (https://www.ietf.org/rfc/rfc1961.txt)
    # @return [Integer]
    USERNAME_PASSWORD = 0x02
  end
end
