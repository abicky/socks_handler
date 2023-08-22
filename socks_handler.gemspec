# frozen_string_literal: true

require_relative "lib/socks_handler/version"

Gem::Specification.new do |spec|
  spec.name = "socks_handler"
  spec.version = SocksHandler::VERSION
  spec.authors = ["abicky"]
  spec.email = ["takeshi.arabiki@gmail.com"]

  spec.summary = "A flexible socksifier for TCP connections created by TCPSocket.new or Socket.tcp"
  spec.description = <<~DESC
    SocksHandler is a flexible socksifier for TCP connections created by `TCPSocket.new` or `Socket.tcp` that solves the following issues:
    1) `SOCKSSocket` is not easy to use, 2) Famous socksifiers such as socksify and proxychains4 don't support rules using domain names.
  DESC
  spec.homepage = "https://github.com/abicky/socks_handler"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
