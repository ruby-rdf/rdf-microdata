$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'rspec'
require 'rdf/isomorphic'
require 'rdf/microdata'
require 'rdf/n3'
require 'rdf/spec'
require 'rdf/spec/matchers'
require 'matchers'

::RSpec.configure do |c|
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.exclusion_filter = {
    :ruby => lambda { |version| !(RUBY_VERSION.to_s =~ /^#{version.to_s}/) },
  }
  c.include(RDF::Spec::Matchers)
end

TMP_DIR = File.join(File.expand_path(File.dirname(__FILE__)), "tmp")

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
  when /@prefix/i then RDF::N3::Reader
  else                 RDF::N3::Reader
  end
end