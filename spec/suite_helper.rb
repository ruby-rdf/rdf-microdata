$:.unshift "."
require 'spec_helper'
require 'spira'
require 'rdf/turtle'
require 'open-uri'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "http://w3c.github.io/microdata-rdf/tests/"
    LOCAL_PATH = ::File.expand_path("../spec-tests", __FILE__) + '/'

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
      case filename_or_url.to_s
      when /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, &block)
      when 'http://www.w3.org/ns/md'
        Kernel.open(RDF::Microdata::Reader::DEFAULT_REGISTRY, &block)
      when /^#{REMOTE_PATH}/
        begin
          #puts "attempt to open #{filename_or_url} locally"
          if response = ::File.open(filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH))
            #puts "use #{filename_or_url} locally"
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

            if block_given?
              begin
                yield response
              ensure
                response.close
              end
            else
              response
            end
          else
            Kernel.open(filename_or_url.to_s, &block)
          end
        rescue Errno::ENOENT
          # Not there, don't run tests
          StringIO.new("")
        end
      else
        Kernel.open(filename_or_url.to_s, &block)
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
      attributes.map do |k, v|
        "\n  #{k}: #{v.inspect}"
      end.join(" ") +
      ">"
    end
  end
end

module Fixtures
  module SuiteTest
    BASE = RDF::URI("http://w3c.github.io/microdata-rdf/tests/")
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
        json['@graph'].
          select {|m| m['@type'] == 'mf:Manifest'}.
          map {|e| Manifest.new(e)}
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e)}
      end
    end

    class Entry < JSON::LD::Resource
      attr_accessor :debug

      # Alias data and query
      def action
        BASE.join(property('action'))
      end

      def registry
        reg = property('registry') ||
          BASE + "test-registry.json"
        BASE.join(reg)
      end

      def result
        BASE.join(property('result'))
      end

      def positiveTest
        !Array(attributes['@type']).join(" ").match(/Negative/)
      end
     
      def negative_test?
        !positive_test?
      end
      
      def inspect
        super.sub('>', "\n" +
        "  positive?: #{positive_test?.inspect}\n" +
        ">"
      )
      end

      def trace; @debug.join("\n"); end
    end
  end
end
