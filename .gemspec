#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

begin
  RUBY_ENGINE
rescue NameError
  RUBY_ENGINE = "ruby"  # Not defined in Ruby 1.8.7
end

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-microdata"
  gem.homepage              = "http://ruby-rdf.github.com/rdf-microdata"
  gem.license               = 'Public Domain' if gem.respond_to?(:license=)
  gem.summary               = "Microdata reader for Ruby."
  gem.description           = gem.summary
  gem.rubyforge_project     = 'rdf-microdata'

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README UNLICENSE VERSION) + Dir.glob('lib/**/*.rb') + Dir.glob('etc/*')
  gem.require_paths         = %w(lib)
  gem.extensions            = %w()
  gem.test_files            = %w()
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 1.9.2'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '>= 1.1'
  gem.add_runtime_dependency     'json',            '>= 1.7.7'
  gem.add_runtime_dependency     'rdf-xsd',         '>= 1.1'
  gem.add_runtime_dependency     'htmlentities',    '>= 4.3.0'

  gem.add_development_dependency 'nokogiri' ,       '>= 1.5.9'
  gem.add_development_dependency 'equivalent-xml' , '>= 0.3.0'
  gem.add_development_dependency 'open-uri-cached', '>= 0.0.5'
  gem.add_development_dependency 'yard' ,           '>= 0.8.5'
  gem.add_development_dependency 'spira',           '= 0.0.12'
  gem.add_development_dependency 'rspec',           '>= 2.13.0'
  gem.add_development_dependency 'rdf-spec',        '>= 1.1'
  gem.add_development_dependency 'rdf-rdfa',        '>= 1.1'
  gem.add_development_dependency 'rdf-turtle',      '>= 1.1'
  gem.add_development_dependency 'rdf-isomorphic',  '>= 1.1'
  gem.post_install_message  = nil
end
