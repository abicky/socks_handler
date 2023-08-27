# frozen_string_literal: true

 class SocksHandler
   module SocketSocksify
     # @param remote_host [String]
     # @param remote_port [Integer, String]
     # @param local_host [String, nil]
     # @param local_port [Integer, String]
     # @param connect_timeout [Integer, Float, nil]
     # @param resolv_timeout [Integer, Float, nil]
     # @return [IO] (The actual type is Socket and IO is just for avoiding RBS::NoTypeFoundError)
     def tcp(remote_host, remote_port, local_host = nil, local_port = nil, connect_timeout: nil, resolv_timeout: nil, &block)
       rule = SocksHandler.find_rule(remote_host)
       return super if rule.nil? || rule.direct

       socket = super(rule.host, rule.port, local_host, local_port, connect_timeout: connect_timeout, resolv_timeout: resolv_timeout, &block)
       begin
         SocksHandler.establish_connection(socket, remote_host, remote_port, rule.username, rule.password)
       rescue
         socket.close
         raise
       end

       socket
     end
   end
 end
