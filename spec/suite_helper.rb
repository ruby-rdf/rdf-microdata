$:.unshift "."
require 'spec_helper'
require 'spira'
require 'rdf/turtle'
require 'open-uri'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "http://www.w3.org/TR/microdata-rdf/tests/"
    LOCAL_PATH = ::File.expand_path("../htmldata/microdata-rdf/tests", __FILE__) + '/'

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, options = {}, &block)
      #puts "open #{filename_or_url}"
      case filename_or_url.to_s
      when /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, &block)
      when /^#{REMOTE_PATH}/
        begin
          #puts "attempt to open #{filename_or_url} locally"
          #puts " => #{filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)}"
          response = ::File.open(filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH))
          case filename_or_url.to_s
          when /\.html$/
            def response.content_type; 'text/html'; end
          when /\.ttl$/
            def response.content_type; 'text/turtle'; end
          when /\.json$/
            def response.content_type; 'application/json'; end
          when /\.jsonld$/
            def response.content_type; 'application/ld+json'; end
          else
            def response.content_type; 'unknown'; end
          end
          #puts "use #{filename_or_url} locally as #{response.content_type}"

          if block_given?
            begin
              yield response
            ensure
              response.close
            end
          else
            response
          end
        rescue Errno::ENOENT
          # Not there, don't run tests
          Kernel.open(path.to_s, &block)
        end
      else
      end
    end
  end
end

module JSON::LD
  # Simple Ruby reflector class to provide native
  # access to JSON-LD objects
  class Resource
    # Object representation of resource
    # @attr [Hash<String => Object] attributes
    attr :attributes

    # ID of this resource
    # @attr [String] id
    attr :id
    
    # A new resource from the parsed graph
    # @param [Hash{String => Object}] node_definition
    def initialize(node_definition)
      @attributes = node_definition
      @attributes.delete('@context') # Don't store with object
      @id = @attributes['@id']
      @anon = @id.nil? || @id.to_s[0,2] == '_:'
    end

    # Values of all properties other than id and type
    def property_values
      attributes.dup.delete_if {|k, v| %(id type).include?(k)}.values
    end

    # Access individual fields, from subject definition
    def property(prop_name); @attributes.fetch(prop_name, nil); end

    # Access individual fields, from subject definition
    def method_missing(method, *args)
      property(method.to_s)
    end

    def inspect
      "<Resource" +
      attributes.dup.keep_if {|k, v| %(@id @type comment).include?(k)}.map do |k, v|
        "\n  #{k}: #{v.inspect}"
      end.join(" ") +
      ">"
    end
  end
end

module Fixtures
  module SuiteTest
    class Manifest < JSON::LD::Resource
      def self.open(file)
        #puts "open: #{file}"
        RDF::Util::File.open_file(file) do |f|
          json = JSON.parse(f.read)
          self.from_jsonld(json)
        end
      end

      # @param [Hash] json framed JSON-LD
      # @return [Array<Manifest>]
      def self.from_jsonld(json)
        json['@graph'].map {|e| Manifest.new(e)}
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e)}
      end
    end

    class Entry < JSON::LD::Resource
      attr_accessor :debug

      # Alias data and query
      def data
        self.action['data']
      end
      
      def query
        self.action['query']
      end
      
      def registry
        self.action.fetch('registry',
          "http://www.w3.org/TR/microdata-rdf/tests/test-registry.json")
      end

      def result
        property('result') == 'true'
      end
      
      def trace; @debug.join("\n"); end
    end
  end
end