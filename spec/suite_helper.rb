$:.unshift "."
require 'spec_helper'
require 'rdf/turtle'
require 'open-uri'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "http://w3c.github.io/microdata-rdf/tests/"
    LOCAL_PATH = ::File.expand_path("../spec-tests", __FILE__) + '/'

    class << self
      alias_method :original_open_file, :open_file
    end

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, **options, &block)
      case
      when filename_or_url.to_s =~ /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, options, &block)
      when (filename_or_url.to_s =~ %r{^#{REMOTE_PATH}} && Dir.exist?(LOCAL_PATH))
        #puts "attempt to open #{filename_or_url} locally"
        localpath = filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)
        response = begin
          ::File.open(localpath)
        rescue Errno::ENOENT => e
          raise IOError, e.message
        end
        document_options = {
          base_uri:     RDF::URI(filename_or_url),
          charset:      Encoding::UTF_8,
          code:         200,
          headers:      {}
        }
        #puts "use #{filename_or_url} locally"
        document_options[:headers][:content_type] = case filename_or_url.to_s
        when /\.html$/    then 'text/html'
        when /\.xhtml$/   then 'application/xhtml+xml'
        when /\.xml$/     then 'application/xml'
        when /\.svg$/     then 'image/svg+xml'
        when /\.ttl$/     then 'text/turtle'
        when /\.ttl$/     then 'text/turtle'
        when /\.jsonld$/  then 'application/ld+json'
        when /\.json$/    then 'application/json'
        else                   'unknown'
        end

        document_options[:headers][:content_type] = response.content_type if response.respond_to?(:content_type)
        # For overriding content type from test data
        document_options[:headers][:content_type] = options[:contentType] if options[:contentType]

        remote_document = RDF::Util::File::RemoteDocument.new(response.read, **document_options)
        if block_given?
          yield remote_document
        else
          remote_document
        end
      else
        original_open_file(filename_or_url, **options, &block)
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
      def self.open(file, &block)
        #puts "open: #{file}"
        RDF::Util::File.open_file(file) do |f|
          json = JSON.parse(f.read)
          block.call(self.from_jsonld(json['@graph'].first))
        end
      end

      # @param [Hash] json framed JSON-LD
      # @return [Array<Manifest>]
      def self.from_jsonld(json)
        Manifest.new(json)
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e)}
      end
    end

    class Entry < JSON::LD::Resource
      attr_accessor :logger

      # Alias data and query
      def action
        BASE.join(property('action'))
      end

      def input
        RDF::Util::File.open_file(action).read
      end

      def registry
        reg = property('registry') ||
          BASE + "test-registry.json"
        BASE.join(reg)
      end

      def result
        BASE.join(property('result')) if property('result')
      end

      def expected
        RDF::Util::File.open_file(result).read
      end

      def positive_test?
        !Array(attributes['@type']).join(" ").match(/Negative/)
      end
     
      def negative_test?
        !positive_test?
      end

      def evaluate?
        Array(attributes['@type']).join(" ").include?("Eval")
      end

      def syntax?
        Array(attributes['@type']).join(" ").include?("Syntax")
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
