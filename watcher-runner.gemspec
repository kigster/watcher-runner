# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require_relative 'lib/watcher/runner/version'

Gem::Specification.new do |spec|
  spec.name    = 'watcher-runner'
  spec.version = Watcher::Runner::VERSION
  spec.authors = ['Konstantin Gredeskoul']
  spec.email   = %w(kigster@gmail.com)

  spec.summary = "Watches a folder and executes a command upon any changes to it."
  spec.license = 'MIT'

  spec.description = "Watches a folder and executes a command upon any changes to it."

  spec.homepage = 'https://github.com/kigster/watcher-runner'

  spec.files                 = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir                = 'exe'
  spec.executables           = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths         = ['lib']
  spec.required_ruby_version = '>= 3.3'

  spec.add_dependency 'tty-cursor'
  spec.add_dependency 'colored2'
  spec.add_dependency 'listen'
end
