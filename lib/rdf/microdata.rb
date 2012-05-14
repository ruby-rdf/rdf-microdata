$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))
require 'rdf'

module RDF
  ##
  # **`RDF::Microdata`** is a Microdata plugin for RDF.rb.
  #
  # @example Requiring the `RDF::Microdata` module
  #   require 'rdf/microdata'
  #
  # @example Parsing RDF statements from an HTML file
  #   RDF::Microdata::Reader.open("etc/foaf.html") do |reader|
  #     reader.each_statement do |statement|
  #       puts statement.inspect
  #     end
  #   end
  #
  # @see http://rdf.rubyforge.org/
  # @see http://www.w3.org/TR/2011/WD-microdata-20110525/
  #
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  module Microdata
    require 'rdf/microdata/format'
    require 'rdf/microdata/vocab'
    autoload :Profile, 'rdf/microdata/profile'
    autoload :Reader,  'rdf/microdata/reader'
    autoload :VERSION, 'rdf/microdata/version'
    
    def self.debug?; @debug; end
    def self.debug=(value); @debug = value; end
  end
end
