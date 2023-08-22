# frozen_string_literal: true

class SocksHandler
  module AuthenticationMethod
    NONE = 0x00
    GSSAPI = 0x01 # Not supported yet (https://www.ietf.org/rfc/rfc1961.txt)
    USERNAME_PASSWORD = 0x02
  end
end
