#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-microdata"
  gem.homepage              = "https://github.com/ruby-rdf/rdf-microdata"
  gem.license               = 'Unlicense'
  gem.summary               = "Microdata reader for Ruby."
  gem.description           = 'Reads HTML Microdata as RDF.'
  gem.metadata           = {
    "documentation_uri" => "https://ruby-rdf.github.io/rdf-microdata",
    "bug_tracker_uri"   => "https://github.com/ruby-rdf/rdf-microdata/issues",
    "homepage_uri"      => "https://github.com/ruby-rdf/rdf-microdata",
    "mailing_list_uri"  => "https://lists.w3.org/Archives/Public/public-rdf-ruby/",
    "source_code_uri"   => "https://github.com/ruby-rdf/rdf-microdata",
  }

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md UNLICENSE VERSION) + Dir.glob('lib/**/*.rb') + Dir.glob('etc/*')
  gem.require_paths         = %w(lib)

  gem.required_ruby_version = '>= 3.0'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '~> 3.3'
  gem.add_runtime_dependency     'rdf-rdfa',        '~> 3.3'
  gem.add_runtime_dependency     'rdf-xsd',         '~> 3.3'
  gem.add_runtime_dependency     'htmlentities',    '~> 4.3'
  gem.add_runtime_dependency     'nokogiri' ,       '~> 1.15', '>= 1.15.4'

  gem.add_development_dependency 'equivalent-xml' , '~> 0.6'
  gem.add_development_dependency 'getoptlong',      '~> 0.2'
  gem.add_development_dependency 'yard' ,           '~> 0.9'
  gem.add_development_dependency 'rspec',           '~> 3.12'
  gem.add_development_dependency 'rspec-its',       '~> 1.3'
  
  gem.add_development_dependency 'rdf-spec',        '~> 3.3'
  gem.add_development_dependency 'rdf-turtle',      '~> 3.3'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 3.3'
  gem.add_development_dependency 'json-ld',         '~> 3.3'

  gem.post_install_message  = nil
end
