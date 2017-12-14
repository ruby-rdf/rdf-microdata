require 'json/ld'
require 'nokogumbo'

module RDF::Microdata
  ##
  # Update DOM to turn Microdata into JSON-LD and parse using the JSON-LD Reader
  class JsonLdReader < JSON::LD::Reader
    # The resulting JSON-LD
    # @return [Hash]
    attr_reader :jsonld

    def self.format(klass = nil)
      if klass.nil?
        RDF::Microdata::Format
      else
        super
      end
    end

    ##
    # Initializes the JsonLdReader instance.
    #
    # @param  [IO, File, String] input
    #   the input stream to read
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see `RDF::Reader#initialize`)
    # @return [reader]
    # @yield  [reader] `self`
    # @yieldparam  [RDF::Reader] reader
    # @yieldreturn [void] ignored
    # @raise [RDF::ReaderError] if _validate_
    def initialize(input = $stdin, options = {}, &block)
      @options = options
      log_info('', "using JSON-LD transformation reader")

      input = case input
      when ::Nokogiri::XML::Document, ::Nokogiri::HTML::Document then input
      else
        # Try to detect charset from input
        options[:encoding] ||= input.charset if input.respond_to?(:charset)
        
        # Otherwise, default is utf-8
        options[:encoding] ||= 'utf-8'
        options[:encoding] = options[:encoding].to_s if options[:encoding]
        input = input.read if input.respond_to?(:read)
        ::Nokogiri::HTML5(input.force_encoding(options[:encoding]))
      end

      # Load registry
      begin
        registry_uri = options[:registry] || RDF::Microdata::DEFAULT_REGISTRY
        log_debug('', "registry = #{registry_uri.inspect}")
        Registry.load_registry(registry_uri)
      rescue JSON::ParserError => e
        log_fatal("Failed to parse registry: #{e.message}", exception: RDF::ReaderError) if (root.nil? && validate?)
      end

      @jsonld = {'@graph' => []}

      # Start with all top-level items
      input.css("[itemscope]").each do |item|
        next if item['itemprop']  # Only top-level items
        jsonld['@graph'] << get_object(item)
      end

      log_debug('', "Transformed document: #{jsonld.to_json(JSON::LD::JSON_STATE)}")

      # Rely on RDFa reader
      super(jsonld.to_json, options, &block)
    end

    private
    # Return JSON-LD representation of an item
    # @param [Nokogiri::XML::Element] item
    # @param [Hash{Nokogiri::XML::Node => Hash}]
    # @return [Hash]
    def get_object(item, memory = {})
      if result = memory[item]
        # Result is a reference to that item; assign a blank-node identifier if necessary
        result['@id'] ||= alloc_bnode
        return result
      end

      result = {}
      memory[item] = result

      # If the item has a global identifier, add an entry to result called "@id" whose value is the global identifier of item.
      result['@id'] = item['itemid'].to_s if item['itemid']

      # If the item has any item types, add an entry to result called "@type" whose value is an array listing the item types of item, in the order they were specified on the itemtype attribute.
      if item['itemtype']
        # Only absolute URLs
        types = item.attribute('itemtype').
          remove.
          to_s.
          split(/\s+/).
          select {|t| RDF::URI(t).absolute?}
        if vocab = types.first
          vocab = Registry.find(vocab) || begin
            type_vocab = vocab.to_s.sub(/([\/\#])[^\/\#]*$/, '\1') unless vocab.nil?
            Registry.new(type_vocab) if type_vocab
          end
          (result['@context'] = {})['@vocab'] = vocab.uri.to_s if vocab
          result['@type'] = types unless types.empty?
        end
      end

      # For each element element that has one or more property names and is one of the properties of the item item, in the order those elements are given by the algorithm that returns the properties of an item, run the following substeps
      item_properties(item).each do |element|
        value = if element['itemscope']
          get_object(element, memory)
        else
          property_value(element)
        end
        element['itemprop'].to_s.split(/\s+/).each do |prop|
          result[prop] ||= [] << value
        end
      end

      result
    end

    ##
    #
    # @param [Nokogiri::XML::Element] item
    # @return [Array<Nokogiri::XML::Element>]
    #   List of property elements for an item
    def item_properties(item)
      results, memory, pending = [], [item], item.children.select(&:element?)
      log_debug(item, "item_properties")

      # If root has an itemref attribute, split the value of that itemref attribute on spaces. For each resulting token ID, if there is an element in the document whose ID is ID, then add the first such element to pending.
      item['itemref'].to_s.split(/\s+/).each do |ref|
        if referenced = referenced = item.at_css("##{ref}")
          pending << referenced
        end
      end

      while !pending.empty?
        current = pending.shift
        # Error
        break if memory.include?(current)
        memory << current

        # If current does not have an itemscope attribute, then: add all the child elements of current to pending.
        pending += current.children.select(&:element?) unless current['itemscope']

        # If current has an itemprop attribute specified and has one or more property names, then add current to results.
        results << current unless current['itemprop'].to_s.split(/\s+/).empty?
      end

      results
    end

    ##
    #
    def property_value(element)
      base = element.base || base_uri
      log_debug(element) {"property_value(#{element.name}): base #{base.inspect}"}
      value = case
      when element.has_attribute?('itemscope')
        {}
      when element.has_attribute?('content')
        if element.language
          {"@value" => element['content'].to_s.strip, language: element.language}
        else
          element['content'].to_s.strip
        end
      when %w(data meter).include?(element.name) && element.attribute('value')
        # XXX parse as number?
        {"@value" => element['value'].to_s.strip}
      when %w(audio embed iframe img source track video).include?(element.name)
        {"@id" => uri(element.attribute('src'), base).to_s}
      when %w(a area link).include?(element.name)
        {"@id" => uri(element.attribute('href'), base).to_s}
      when %w(object).include?(element.name)
        {"@id" => uri(element.attribute('data'), base).to_s}
      when %w(time).include?(element.name)
        # use datatype?
        (element.attribute('datetime') || element.text).to_s.strip
      else
        if element.language
          {"@value" => element.inner_text.to_s.strip, language: element.language}
        else
          element.inner_text.to_s.strip
        end
      end
      log_debug(element) {"  #{value.inspect}"}
      value
    end

    # Allocate a new blank node identifier
    # @return [String]
    def alloc_bnode
      @bnode_base ||= "_:a"
      res = @bnode_base
      @bnode_base = res.succ
      res
    end

    # Fixme, what about xml:base relative to element?
    def uri(value, base = nil)
      value = if base
        base = uri(base) unless base.is_a?(RDF::URI)
        base.join(value.to_s)
      else
        RDF::URI(value.to_s)
      end
      value.validate! if validate?
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
    end
  end
end

# Monkey Patch Nokogiri
module Nokogiri::XML
  class Element

    ##
    # Get any xml:base in effect for this element
    def base
      if @base.nil?
        @base = attributes['xml:base'] ||
        (parent && parent.element? && parent.base) ||
        false
      end

      @base == false ? nil : @base
    end


    ##
    # Get any xml:lang or lang in effect for this element
    def language
      if @language.nil?
        language = case
        when self["xml:lang"]
          self["xml:lang"].to_s
        when self["lang"]
          self["lang"].to_s
        else
          parent && parent.element? && parent.language
        end
      end
      @language == false ? nil : @language
    end

  end
end
