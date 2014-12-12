$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift File.dirname(__FILE__)

require "bundler/setup"
require 'rspec'
require 'rdf/isomorphic'
require 'rdf/microdata'
require 'rdf/turtle'
require 'rdf/spec/matchers'
require 'restclient/components'
require 'rack/cache'
require 'matchers'

# Create and maintain a cache of downloaded URIs
URI_CACHE = File.expand_path(File.join(File.dirname(__FILE__), "uri-cache"))
Dir.mkdir(URI_CACHE) unless File.directory?(URI_CACHE)
# Cache client requests
RestClient.enable Rack::Cache,
  verbose:      false, 
  metastore:   "file:" + ::File.expand_path("../uri-cache/meta", __FILE__),
  entitystore: "file:" + ::File.expand_path("../uri-cache/body", __FILE__)

::RSpec.configure do |c|
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
  c.exclusion_filter = {
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
  when /@prefix/i then RDF::Turtle::Reader
  else                 RDF::Turtle::Reader
  end
end
