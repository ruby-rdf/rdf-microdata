#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-microdata"
  gem.homepage              = "http://github.com/gkellogg/rdf-microdata"
  gem.license               = 'Public Domain' if gem.respond_to?(:license=)
  gem.summary               = "Microdata reader for Ruby."
  gem.description           = gem.summary
  gem.rubyforge_project     = 'rdf-microdata'

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README UNLICENSE VERSION) + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)
  gem.extensions            = %w()
  gem.test_files            = %w()
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 1.8.1'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '>= 0.3.4'
  gem.add_runtime_dependency     'nokogiri',        '>= 1.4.4'
  gem.add_runtime_dependency     'rdf-xsd',         '>= 0.3.4'
  gem.add_development_dependency 'yard' ,           '>= 0.6.0'
  gem.add_development_dependency 'rspec',           '>= 2.5.0'
  gem.add_development_dependency 'rdf-spec',        '>= 0.3.4'
  gem.add_development_dependency 'rdf-turtle',      '>= 0.1.0'
  gem.add_development_dependency 'rdf-isomorphic',  '>= 0.3.4'
  gem.post_install_message  = nil
end