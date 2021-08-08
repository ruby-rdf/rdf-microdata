$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)

require "bundler/setup"
require 'rspec'
require 'rdf/isomorphic'
require 'rdf/microdata'
require 'rdf/turtle'
require 'rdf/spec'
require 'rdf/spec/matchers'

::RSpec.configure do |c|
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
  c.exclusion_filter = {
  }
  c.include(RDF::Spec::Matchers)
end

require 'byebug'; byebug
begin
  require 'simplecov'
  require 'simplecov-lcov'
  require 'coveralls'

  SimpleCov::Formatter::LcovFormatter.config do |config|
    #Coveralls is coverage by default/lcov. Send info results
    config.report_with_single_file = true
    config.single_report_path = 'coverage/lcov.info'
  end

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ])
  SimpleCov.start do
    add_filter "/spec/"
  end
rescue LoadError => e
  STDERR.puts "Coverage Skipped: #{e.message}"
end

# Heuristically detect the input stream
def detect_format(stream)
  # Got to look into the file to see
  if stream.is_a?(IO) || stream.is_a?(StringIO)
    stream.rewind
    string = stream.read(1000)
    stream.rewind
  else
    string = stream.to_s
  end
  case string
  when /<html/i   then RDF::Microdatea::Reader
  when /@prefix/i then RDF::Turtle::Reader
  else                 RDF::Turtle::Reader
  end
end
