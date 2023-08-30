require "socket"
require "stringio"

require "socks_handler"

module SocksHandler
  class UDPSocket < ::UDPSocket
    include SocksHandler

    # @return [Integer]
    MAX_REPLY_SIZE = 262 # When the length of the domain name is 255

    # @!method connect_socks_server(host, port)
    # @param host [String]
    # @param port [Integer]
    # @return [Integer]
    alias_method :connect_socks_server, :connect


    # @param host [String]
    # @param port [Integer]
    # @return [Integer]
    # @see UDPSocket#connect
    def connect(host, port)
      @host = host
      @port = port
      0
    end

    # @param maxlen [Integer]
    # @param flags [Integer]
    # @return [String]
    # @see UDPSocket#recv
    def recv(maxlen, flags = 0)
      resp, _ = recvfrom(maxlen, flags)
      resp
    end

    # @!method recvfrom_socks_server(maxlen, flags = 0)
    # @param maxlen [Integer]
    # @param maxlen [Integer]
    # @param flags [Integer]
    # @return [Array(String, Array(String, Integer, String, String))]
    alias_method :recvfrom_socks_server, :recvfrom

    # @param maxlen [Integer]
    # @param flags [Integer]
    # @return [Array(String, Array(String, Integer, String, String))]
    # @see UDPSocket#recvfrom)
    def recvfrom(maxlen, flags = 0)
      recvfrom_via(method(:recvfrom_socks_server), maxlen + MAX_REPLY_SIZE, flags)
    end

    # @!method recvfrom_socks_server_nonblock(maxlen, flags = 0)
    # @param maxlen [Integer]
    # @param flags [Integer]
    # @return [Array(String, Array(String, Integer, String, String))]
    alias_method :recvfrom_socks_server_nonblock, :recvfrom_nonblock

    # @param maxlen [Integer]
    # @param flags [Integer]
    # @return [Array(String, Array(String, Integer, String, String))]
    # @see UDPSocket#recvfrom_nonblock
    def recvfrom_nonblock( maxlen, flags = 0)
      recvfrom_via(method(:recvfrom_socks_server_nonblock), maxlen + MAX_REPLY_SIZE, flags)
    end

    # @param mesg [String]
    # @param flags [Integer]
    # @param host [String]
    # @param port [Integer, String]
    # @return [Integer]
    # @see UDPSocket#send
    def send(mesg, flags, host = nil, port = nil)
      if @host &&  @port && (host || port)
        raise Errno::EISCONN, "Socket is already connected"
      end

      host ||= @host
      port ||= @port
      if port.nil?
        if host.nil?
          raise Errno::EDESTADDRREQ, "Destination address required"
        else
          host, port = (host.is_a?(String) ? Addrinfo.new(host) : host).getnameinfo
        end
      end

      request = [0x00, 0x00, 0x00].pack("C*") # Currently, the fragment number is fixed to 0
      request << build_destination_packets(host, port)
      request << [mesg].pack("a*")
      super(request, flags)
    end

    private

    # @param method [Method]
    # @param maxlen [Integer]
    # @param flags [Integer]
    # @return [Array(String, Array(String, Integer, String, String))]
    def recvfrom_via(method, maxlen, flags)
      data, inet_addr = method.call(maxlen + MAX_REPLY_SIZE, flags)
      response = StringIO.new(data)
      process_reply(response)
      [response.read, inet_addr]
    end
  end
end
