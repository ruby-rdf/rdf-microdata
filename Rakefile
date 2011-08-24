require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'

namespace :gem do
  desc "Build the rdf-microdata-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build .gemspec && mv rdf-microdata-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-microdata-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-microdata-#{File.read('VERSION').chomp}.gem"
  end
end

desc 'Run specifications'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = %w(--options spec/spec.opts) if File.exists?('spec/spec.opts')
end

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

namespace :doc do
  YARD::Rake::YardocTask.new

  desc "Generate HTML report specs"
  RSpec::Core::RakeTask.new("spec") do |spec|
    spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
  end
end

task :default => :spec
