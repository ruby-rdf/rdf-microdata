source "http://rubygems.org"

gemspec

gem 'rdf',      git: "git://github.com/ruby-rdf/rdf.git", branch: "develop"
gem "rdf-xsd",  git: "git://github.com/ruby-rdf/rdf-xsd.git", branch: "develop"
gem "rdf-rdfa", git: "git://github.com/ruby-rdf/rdf-rdfa.git", branch: "develop"

group :development do
  gem 'rdf-spec',           git: "git://github.com/ruby-rdf/rdf-spec.git", branch: "develop"
  gem "rdf-isomorphic",     git: "git://github.com/ruby-rdf/rdf-isomorphic.git"
  gem "rdf-turtle",         git: "git://github.com/ruby-rdf/rdf-turtle.git", branch: "develop"
  gem "rdf-aggregate-repo", git: "git://github.com/ruby-rdf/rdf-aggregate-repo.git", branch: "develop"
end

group :debug do
  gem "wirble"
  gem "byebug", platform: :mri_21
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
  gem 'json'
end
