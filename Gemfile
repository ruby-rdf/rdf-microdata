source "http://rubygems.org"

gemspec

gem "rdf",            git: "https://github.com/ruby-rdf/rdf",      branch: "develop"
gem "rdf-rdfa",       git: "https://github.com/ruby-rdf/rdf-rdfa", branch: "develop"
gem "rdf-xsd",        git: "https://github.com/ruby-rdf/rdf-xsd",  branch: "develop"
gem "nokogumbo",      '~> 1.4'

group :development do
  gem 'linkeddata'
  gem 'ebnf',               git: "https://github.com/dryruby/ebnf",                 branch: "develop"
  gem 'rdf-aggregate-repo', git: "https://github.com/ruby-rdf/rdf-aggregate-repo",  branch: "develop"
  gem 'rdf-isomorphic',     git: "https://github.com/ruby-rdf/rdf-isomorphic",      branch: "develop"
  gem "rdf-spec",           git: "https://github.com/ruby-rdf/rdf-spec",            branch: "develop"
  gem 'rdf-turtle',         git: "https://github.com/ruby-rdf/rdf-turtle",          branch: "develop"
  gem 'sxp',                git: "https://github.com/dryruby/sxp.rb",               branch: "develop"
end

group :debug do
  gem "byebug", platform: :mri
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
