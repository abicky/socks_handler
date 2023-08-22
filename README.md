# SocksHandler

SocksHandler is a flexible socksifier for TCP connections created by `TCPSocket.new` or `Socket.tcp` that solves the following issues:

* `SOCKSSocket` is not easy to use
    - It is unavailable unless ruby is built with `--enable-socks`, and even if it is available, we cannot use domain names that the network where the program runs cannot resolve since socket classes, including `SOCKSSocket`, call `getaddrinfo` at initialization.
* Famous socksifiers such as [socksify](https://www.inet.no/dante/doc/1.3.x/socksify.1.html) and [proxychains4](https://github.com/rofl0r/proxychains-ng) don't support rules using domain names
    - Besides, they don't work on macOS if Ruby is managed by rbenv maybe due to SIP (System Integrity Protection)

For more details, see the section "Related Work."

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add socks_handler

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install socks_handler

## Usage

Assuming that a SOCKS server that can access the host "nginx" is listening on 127.0.0.1:1080. You can prepare such an environment with the following docker-compose.yml.

```yaml
version: "2.4"
services:
  sockd:
    image: wernight/dante
    ports:
      - 1080:1080

  nginx:
    image: nginx
```

Here is an example to create a socket that can access the host "nginx" from the Docker host:

```ruby
require "socks_handler"

socket = TCPSocket.new("127.0.0.1", 1080) # or Socket.tcp("127.0.0.1", 1080)
SocksHandler.establish_connection(socket, "nginx", 80)

socket.write(<<~REQUEST.gsub("\n", "\r\n"))
  HEAD / HTTP/1.1
  Host: nginx

REQUEST
puts socket.gets #=> HTTP/1.1 200 OK
```

If you want to access the host through the SOCKS server implicitly, you can use `SocksHandler.socksify` as follows:

```ruby
require "socks_handler"

SocksHandler.socksify([
  SocksHandler::ProxyAccessRule.new(
    remote_host_patterns: ["nginx"],
    socks_server: "127.0.0.1:1080",
  )
])

socket = TCPSocket.new("nginx", 80)
socket.write(<<~REQUEST.gsub("\n", "\r\n"))
  HEAD / HTTP/1.1
  Host: nginx

REQUEST
puts socket.gets #=> HTTP/1.1 200 OK
```

With `SocksHandler.socksify`, other methods using `TCPSocket.new` or `Socket.tcp` also access the remote host through the SOCKS server:

```ruby
require "net/http"
require "socks_handler"

SocksHandler.socksify([
  SocksHandler::ProxyAccessRule.new(
    remote_host_patterns: ["nginx"],
    socks_server: "127.0.0.1:1080",
  )
])

Net::HTTP.start("nginx", 80) do |http|
  pp http.head("/") #=> #<Net::HTTPOK 200 OK readbody=true>
end
```

For more details, see the document of `SocksHandler.socksify`:

```
$ ri SocksHandler.socksify
```

## Limitation

As `SocksHandler` only socksifies TCP connections created by `TCPSocket.new` or `Socket.tcp`, it doesn't socksify connections created by native extensions.

For example, assuming that a SOCKS server that can access the host "mysql" is listening on 127.0.0.1:1080 as follows:

```yaml
version: "2.4"
services:
  sockd:
    image: wernight/dante

  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: password
```

The following code raises `Mysql2::Error::ConnectionError` because the gem "mysql2" tries to connect to the server via a native extension:

```ruby
require "mysql2"

SocksHandler.socksify([
  SocksHandler::ProxyAccessRule.new(
    remote_host_patterns: ["mysql"],
    socks_server: "127.0.0.1:1080",
  )
])

client = Mysql2::Client.new(
  host: "mysql",
  port: 3306,
  username: "root",
  password: "password",
)
client.ping
#=> Unknown MySQL server host 'mysql' (8) (Mysql2::Error::ConnectionError)
```

## Related Work

### Gems

The following projects provide similar gems:

* [ruby-proxifier](https://github.com/samuelkadolph/ruby-proxifier)
    - This project seems to no longer be maintained.
* [socksify-ruby](https://github.com/astro/socksify-ruby)

### SOCKSSocket

On macOS, you can build ruby with `SOCKSSocket` as follows:

```
$ brew install dante bison
$ git clone https://github.com/ruby/ruby.git
$ cd ruby
$ git checkout v3_2_2
$ ./configure --enable-socks
$ PATH="/usr/local/opt/bison/bin:$PATH" make -j$(nproc) install
$ cat <<EOF >/etc/socks.conf
route {
  from: 0.0.0.0/0 to: 0.0.0.0/0 via: 127.0.0.1 port = 1080
  proxyprotocol: socks_v5
  method: none
}
EOF
```

Here is example code to access nginx launched using docker-compose.yml in the section "Usage":

```ruby
require "socket"

ip = `docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker compose ps -q nginx)`.chomp
[ip, "nginx"].each do |host|
  puts "Send an HTTP request to #{host}"
  socket = SOCKSSocket.new(host, 80)
  socket.write(<<~REQUEST.gsub("\n", "\r\n"))
    HEAD / HTTP/1.1
    Host: nginx

  REQUEST
  puts "Received: #{socket.gets}"
end
```

As you can see below, we cannot use the domain name "nginx" since socket classes, including `SOCKSSocket`, call `getaddrinfo` at initialization:

```
$ /usr/local/bin/ruby /path/to/code.rb
Send an HTTP request to 192.168.160.4
Received: HTTP/1.1 200 OK
Send an HTTP request to nginx
code.rb:6:in `initialize': getaddrinfo: nodename nor servname provided, or not known (SocketError)
        from code.rb:6:in `new'
        from code.rb:6:in `block in <main>'
        from code.rb:4:in `each'
        from code.rb:4:in `<main>'
```

### ProxyChains-NG

[ProxyChains-NG](https://github.com/rofl0r/proxychains-ng) is a socksifier that works well even on macOS.

On macOS, you can install it as follows:

```
$ brew install proxychains-ng
```

Then edit `/usr/local/etc/proxychains.conf` to use the socks server listening on 127.0.0.1:1080:

```
[ProxyList]
socks5 127.0.0.1 1080
```

ProxyChains-NG can socksify even connections created by native extensions. Here is example code to demonstrate it:

```ruby
require "net/http"
require "mysql2"

Net::HTTP.start("nginx", 80) do |http|
  pp http.head("/")
end

client = Mysql2::Client.new(
  host: "mysql",
  port: 3306,
  username: "root",
  password: "password",
)
puts client.ping
```

As you can see below, the program can access containers though the socks server:

```
$ proxychains4 /usr/local/bin/ruby /path/to/code.rb
[proxychains] config file found: /usr/local/etc/proxychains.conf
[proxychains] preloading /usr/local/Cellar/proxychains-ng/4.16/lib/libproxychains4.dylib
[proxychains] DLL init: proxychains-ng 4.16
[proxychains] Strict chain  ...  127.0.0.1:1080  ...  nginx:80  ...  OK
#<Net::HTTPOK 200 OK readbody=true>
[proxychains] Strict chain  ...  127.0.0.1:1080  ...  mysql:3306  ...  OK
true
```

However, it doesn't work if Ruby is managed by rbenv:

```
$ rbenv local
3.2.2
$ proxychains4 ruby /path/to/code.rb
[proxychains] config file found: /usr/local/etc/proxychains.conf
[proxychains] preloading /usr/local/Cellar/proxychains-ng/4.16/lib/libproxychains4.dylib
/Users/arabiki/.anyenv/envs/rbenv/versions/3.2.2/lib/ruby/3.2.0/net/http.rb:1271:in `initialize': Failed to open TCP connection to nginx:80 (getaddrinfo: nodename nor servname provided, or not known) (SocketError)
-- snip --
```

Maybe the reason is that macOS doesn't allow any system binaries to preload libraries and rbenv uses `/usr/bin/env`:

```
$ proxychains4 env /usr/local/bin/ruby /path/to/code.rb
[proxychains] config file found: /usr/local/etc/proxychains.conf
[proxychains] preloading /usr/local/Cellar/proxychains-ng/4.16/lib/libproxychains4.dylib
/usr/local/lib/ruby/3.2.0/net/http.rb:1271:in `initialize': Failed to open TCP connection to nginx:80 (getaddrinfo: nodename nor servname provided, or not known) (SocketError)
-- snip --
```

Although ProxyChains-NG works well in almost all cases, it cannot use domain names to determine whether to access them through a socks proxy.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/abicky/socks_handler.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
