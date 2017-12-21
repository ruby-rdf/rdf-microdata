#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-microdata"
  gem.homepage              = "http://ruby-rdf.github.com/rdf-microdata"
  gem.license               = 'Unlicense'
  gem.summary               = "Microdata reader for Ruby."
  gem.description           = 'Reads HTML Microdata as RDF.'

  gem.authors               = %w(Gregg Kellogg)
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md UNLICENSE VERSION) + Dir.glob('lib/**/*.rb') + Dir.glob('etc/*')
  gem.require_paths         = %w(lib)
  gem.extensions            = %w()
  gem.test_files            = %w()
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 2.2.2'
  gem.requirements          = []
  #gem.add_runtime_dependency     'rdf',             '~> 2.2', '>= 2.2.8'
  #gem.add_runtime_dependency     'rdf-xsd',         '~> 2.2'
  gem.add_runtime_dependency     'rdf',             '>= 2.2.8', '< 4.0'
  gem.add_runtime_dependency     'rdf-xsd',         '>= 2.2', '< 4.0'
  gem.add_runtime_dependency     'htmlentities',    '~> 4.3'
  gem.add_runtime_dependency     'nokogiri' ,       '~> 1.8'

  gem.add_development_dependency 'equivalent-xml' , '~> 0.6'
  gem.add_development_dependency 'yard' ,           '~> 0.9.12'
  gem.add_development_dependency 'rspec',           '~> 3.6'
  gem.add_development_dependency 'rspec-its',       '~> 1.2'
  
  #gem.add_development_dependency 'json-ld',         '~> 2.1'
  #gem.add_development_dependency 'rdf-spec',        '~> 2.2'
  #gem.add_development_dependency 'rdf-rdfa',        '~> 2.2'
  #gem.add_development_dependency 'rdf-turtle',      '~> 2.2'
  #gem.add_development_dependency 'rdf-isomorphic',  '~> 2.2'
  gem.add_development_dependency 'json-ld',         '>= 2.1', '< 4.0'
  gem.add_development_dependency 'rdf-spec',        '>= 2.2', '< 4.0'
  gem.add_development_dependency 'rdf-rdfa',        '>= 2.2', '< 4.0'
  gem.add_development_dependency 'rdf-turtle',      '>= 2.2', '< 4.0'
  gem.add_development_dependency 'rdf-isomorphic',  '>= 2.2', '< 4.0'

  # Rubinius has it's own dependencies
  if RUBY_ENGINE == "rbx" && RUBY_VERSION >= "2.1.0"
     gem.add_runtime_dependency     "racc"
  end

  gem.post_install_message  = nil
end
