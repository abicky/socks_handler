# frozen_string_literal: true

 class SocksHandler
   module SocketSocksify
     def tcp(remote_host, remote_port, local_host = nil, local_port = nil, connect_timeout: nil)
       rule = SocksHandler.find_rule(remote_host)
       return super if rule.nil? || rule.direct

       socket = super(rule.host, rule.port, local_host, local_port, connect_timeout: connect_timeout)
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
