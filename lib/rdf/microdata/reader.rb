require 'nokogiri'
require 'rdf/xsd'
require 'json'

module RDF::Microdata
  ##
  # An Microdata parser in Ruby
  #
  # Based on processing rules, amended with the following:
  #
  # @see http://dvcs.w3.org/hg/htmldata/raw-file/0d6b89f5befb/microdata-rdf/index.html
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  class Reader < RDF::Reader
    format Format
    include Expansion
    URL_PROPERTY_ELEMENTS = %w(a area audio embed iframe img link object source track video)
    DEFAULT_REGISTRY = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "etc", "registry.json"))

    # @private
    class CrawlFailure < StandardError; end

    # @!attribute [r] implementation
    # @return [Module] Returns the HTML implementation module for this reader instance.
    attr_reader :implementation

    ##
    # Returns the base URI determined by this reader.
    #
    # @example
    #   reader.prefixes[:dc]  #=> RDF::URI('http://purl.org/dc/terms/')
    #
    # @return [Hash{Symbol => RDF::URI}]
    # @since  0.3.0
    def base_uri
      @options[:base_uri]
    end

    # Interface to registry
    class Registry
      # @!attribute [r] uri
      # @return [RDF::URI] Prefix of vocabulary
      attr_reader :uri

      ##
      # Initialize the registry from a URI or file path
      #
      # @param [String] registry_uri
      def self.load_registry(registry_uri)
        return if @registry_uri == registry_uri
        
        json = RDF::Util::File.open_file(registry_uri) { |f| JSON.load(f) }

        @prefixes = {}
        json.each do |prefix, elements|
          next unless elements.is_a?(Hash)
          propertyURI = elements.fetch("propertyURI", "vocabulary").to_sym
          multipleValues = elements.fetch("multipleValues", "unordered").to_sym
          properties = elements.fetch("properties", {})
          @prefixes[prefix] = Registry.new(prefix, propertyURI, multipleValues, properties)
        end
        @registry_uri = registry_uri
      end
      
      ##
      # True if registry has already been loaded
      def self.loaded?
        @prefixes.is_a?(Hash)
      end

      ##
      # Initialize registry for a particular prefix URI
      #
      # @param [RDF::URI] prefixURI
      # @param [#to_sym] propertyURI (:vocabulary)
      # @param [#to_sym] multipleValues (:unordered)
      # @param [Hash] properties ({})
      def initialize(prefixURI, propertyURI = :vocabulary, multipleValues = :unordered, properties = {})
        @uri = prefixURI
        @scheme = propertyURI.to_sym
        @multipleValues = multipleValues.to_sym
        @properties = properties
        if @scheme == :vocabulary
          @property_base = prefixURI.to_s
          # Append a '#' for fragment if necessary
          @property_base += '#' unless %w(/ #).include?(@property_base[-1,1])
        else
          @property_base = 'http://www.w3.org/ns/md?type='
        end
      end

      ##
      # Find a registry entry given a type URI
      #
      # @param [RDF::URI] type
      # @return [Registry]
      def self.find(type) 
        k = @prefixes.keys.detect {|key| type.to_s.index(key) == 0 }
        @prefixes[k] if k
      end
      
      ##
      # Generate a predicateURI given a `name`
      #
      # @param [#to_s] name
      # @param [Hash{}] ec Evaluation Context
      # @return [RDF::URI]
      def predicateURI(name, ec)
        u = RDF::URI(name)
        # 1) If _name_ is an _absolute URL_, return _name_ as a _URI reference_
        return u if u.absolute?
        
        n = frag_escape(name)
        if ec[:current_type].nil?
          # 2) If current type from context is null, there can be no current vocabulary.
          #    Return the URI reference that is the document base with its fragment set to the fragment-escaped value of name
          u = RDF::URI(ec[:document_base].to_s)
          u.fragment = frag_escape(name)
          u
        elsif @scheme == :vocabulary
          # 4) If scheme is vocabulary return the URI reference constructed by appending the fragment escaped value of name to current vocabulary, separated by a U+0023 NUMBER SIGN character (#) unless the current vocabulary ends with either a U+0023 NUMBER SIGN character (#) or SOLIDUS U+002F (/).
          RDF::URI(@property_base + n)
        else  # @scheme == :contextual
          if ec[:current_name].to_s.index(@property_base) == 0
            # 5.2) return the concatenation of s, a U+002E FULL STOP character (.) and the fragment-escaped value of name.
            RDF::URI(ec[:current_name] + '.' + n)
          else
            # 5.3) return the concatenation of http://www.w3.org/ns/md?type=, the fragment-escaped value of current type, the string &prop=, and the fragment-escaped value of name
            RDF::URI(@property_base +
                     frag_escape(ec[:current_type]) +
                     '&prop=' + n)
          end
        end
      end

      ##
      # Turn a predicateURI into a simple token
      # @param [RDF::URI] predicateURI
      # @return [String]
      def tokenize(predicateURI)
        case @scheme
        when :vocabulary
          predicateURI.to_s.sub(@property_base, '')
        when :contextual
          predicateURI.to_s.split('?prop=').last.split('.').last
        end
      end

      ##
      # Determine if property should be serialized as a list or not
      # @param [RDF::URI] predicateURI
      # @return [Boolean]
      def as_list(predicateURI)
        tok = tokenize(predicateURI)
        if @properties[tok].is_a?(Hash) &&
           @properties[tok].has_key?("multipleValues")
          @properties[tok]["multipleValues"].to_sym == :list
        else
          @multipleValues == :list
        end
      end

      ##
      # Yield a equivalentProperty or subPropertyOf if appropriate
      # @param [RDF::URI] predicateURI
      # @yield statement
      # @yieldparam [RDF::Statement] statement
      # @return [Boolean]
      def expand(predicateURI)
        tok = tokenize(predicateURI)
        if @properties[tok].is_a?(Hash)
          if value = @properties[tok]["equivalentProperty"]
            Array(value).each do |v|
              yield RDF::Statement.new(predicateURI,
                                       RDF::OWL.equivalentProperty,
                                       RDF::URI(v))
            end
          elsif value = @properties[tok]["subPropertyOf"]
            Array(value).each do |v|
              yield RDF::Statement.new(predicateURI,
                                       RDF::RDFS.subPropertyOf,
                                       RDF::URI(v))
            end
          end
          value = @properties[tok]
        end
      end

      ##
      # Fragment escape a name
      def frag_escape(name)
        name.to_s.gsub(/["#%<>\[\\\]^{|}]/) {|c| '%' + c.unpack('H2' * c.bytesize).join('%').upcase}
      end
    end

    ##
    # Initializes the Microdata reader instance.
    #
    # @param  [Nokogiri::HTML::Document, Nokogiri::XML::Document, IO, File, String] input
    #   the input stream to read
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @option options [Encoding] :encoding     (Encoding::UTF_8)
    #   the encoding of the input stream (Ruby 1.9+)
    # @option options [Boolean]  :validate     (false)
    #   whether to validate the parsed statements and values
    # @option options [Boolean]  :canonicalize (false)
    #   whether to canonicalize parsed literals
    # @option options [Boolean]  :intern       (true)
    #   whether to intern all parsed URIs
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when resolving relative URIs
    # @option options [#to_s]    :registry_uri (DEFAULT_REGISTRY)
    # @option options [Boolean]  :vocab_expansion (true)
    #   whether to perform OWL2 expansion on the resulting graph
    # @option options [Array] :debug
    #   Array to place debug messages
    # @return [reader]
    # @yield  [reader] `self`
    # @yieldparam  [RDF::Reader] reader
    # @yieldreturn [void] ignored
    # @raise [Error] Raises `RDF::ReaderError` when validating
    def initialize(input = $stdin, options = {}, &block)
      super do
        @debug = options[:debug]
        @vocab_expansion = options.fetch(:vocab_expansion, true)

        @library = :nokogiri

        require "rdf/microdata/reader/#{@library}"
        @implementation = Nokogiri
        self.extend(@implementation)

        initialize_html(input, options) rescue raise RDF::ReaderError.new($!.message)

        if (root.nil? && validate?)
          raise RDF::ReaderError, "Empty Document"
        end
        errors = doc_errors.reject {|e| e.to_s =~ /Tag (audio|source|track|video|time) invalid/}
        raise RDF::ReaderError, "Syntax errors:\n#{errors}" if !errors.empty? && validate?

        add_debug(@doc, "library = #{@library}, expand = #{@vocab_expansion}")

        # Load registry
        begin
          registry_uri = options[:registry_uri] || DEFAULT_REGISTRY
          add_debug(@doc, "registry = #{registry_uri}")
          Registry.load_registry(registry_uri)
        rescue JSON::ParserError => e
          raise RDF::ReaderError, "Failed to parse registry: #{e.message}"
        end
        
        if block_given?
          case block.arity
            when 0 then instance_eval(&block)
            else block.call(self)
          end
        end
      end
    end

    ##
    # Iterates the given block for each RDF statement in the input.
    #
    # Reads to graph and performs expansion if required.
    #
    # @yield  [statement]
    # @yieldparam [RDF::Statement] statement
    # @return [void]
    def each_statement(&block)
      if block_given?
        if @vocab_expansion
          @vocab_expansion = false
          expand.each_statement(&block)
          @vocab_expansion = true
        else
          @callback = block

          # parse
          parse_whole_document(@doc, base_uri)
        end
      end
      enum_for(:each_statement)
    end

    ##
    # Iterates the given block for each RDF triple in the input.
    #
    # @yield  [subject, predicate, object]
    # @yieldparam [RDF::Resource] subject
    # @yieldparam [RDF::URI]      predicate
    # @yieldparam [RDF::Value]    object
    # @return [void]
    def each_triple(&block)
      if block_given?
        each_statement do |statement|
          block.call(*statement.to_triple)
        end
      end
      enum_for(:each_triple)
    end
    
    private

    # Keep track of allocated BNodes
    def bnode(value = nil)
      @bnode_cache ||= {}
      @bnode_cache[value.to_s] ||= RDF::Node.new(value)
    end
    
    # Figure out the document path, if it is an Element or Attribute
    def node_path(node)
      "<#{base_uri}>#{node.respond_to?(:display_path) ? node.display_path : node}"
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [Nokogiri::XML::Node, #to_s] node XML Node or string for showing context
    # @param [String] message
    # @yieldreturn [String] appended to message, to allow for lazy-evaulation of message
    def add_debug(node, message = "")
      return unless ::RDF::Microdata.debug? || @debug
      message = message + yield if block_given?
      puts "#{node_path(node)}: #{message}" if ::RDF::Microdata::debug?
      @debug << "#{node_path(node)}: #{message}" if @debug.is_a?(Array)
    end

    def add_error(node, message)
      add_debug(node, message)
      raise RDF::ReaderError, message if validate?
    end
    
    # add a statement, object can be literal or URI or bnode
    #
    # @param [Nokogiri::XML::Node, any] node XML Node or string for showing context
    # @param [URI, BNode] subject the subject of the statement
    # @param [URI] predicate the predicate of the statement
    # @param [URI, BNode, Literal] object the object of the statement
    # @return [Statement] Added statement
    # @raise [ReaderError] Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_triple(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
      raise RDF::ReaderError, "#{statement.inspect} is invalid" if validate? && statement.invalid?
      add_debug(node) {"statement: #{RDF::NTriples.serialize(statement)}"}
      @callback.call(statement)
    end

    # Parsing a Microdata document (this is *not* the recursive method)
    def parse_whole_document(doc, base)
      base = doc_base(base)
      options[:base_uri] = if (base)
        # Strip any fragment from base
        base = base.to_s.split('#').first
        base = uri(base)
      else
        base = RDF::URI("")
      end
      
      add_debug(nil) {"parse_whole_doc: base='#{base}'"}

      ec = {
        :memory             => {},
        :current_name       => nil,
        :current_type       => nil,
        :current_vocabulary => nil,
        :document_base      => base,
      }
      items = []
      # 1) For each element that is also a top-level item run the following algorithm:
      #
      #   1) Generate the triples for an item item, using the evaluation context.
      #      Let result be the (URI reference or blank node) subject returned.
      #   2) Append result to item list.
      getItems.each do |el|
        result = generate_triples(el, ec)
        items << result
      end
      
      # 2) Generate an RDF Collection list from
      #    the ordered list of values. Set value to the value returned from generate an RDF Collection.
      value = generateRDFCollection(root, items)

      # 3) Generate the following triple:
      #     subject Document base
      #     predicate http://www.w3.org/1999/xhtml/microdata#item
      #     object value
      add_triple(doc, base, RDF::MD.item, value) if value

      add_debug(doc, "parse_whole_doc: traversal complete")
    end

    ##
    # Generate triples for an item
    # @param [RDF::Resource] item
    # @param [Hash{Symbol => Object}] ec
    # @option ec [Hash{Nokogiri::XML::Element} => RDF::Resource] memory
    # @option ec [RDF::Resource] :current_type
    # @return [RDF::Resource]
    def generate_triples(item, ec = {})
      memory = ec[:memory]
      # 1) If there is an entry for item in memory, then let subject be the subject of that entry.
      #    Otherwise, if item has a global identifier and that global identifier is an absolute URL,
      #    let subject be that global identifier. Otherwise, let subject be a new blank node.
      subject = if memory.include?(item.node)
        memory[item.node][:subject]
      elsif item.has_attribute?('itemid')
        uri(item.attribute('itemid'), item.base || base_uri)
      end || RDF::Node.new
      memory[item.node] ||= {}

      add_debug(item) {"gentrips(2): subject=#{subject.inspect}, current_type: #{ec[:current_type]}"}

      # 2) Add a mapping from item to subject in memory, if there isn't one already.
      memory[item.node][:subject] ||= subject
      
      # 3) For each type returned from element.itemType of the element defining the item.
      type = nil
      item.attribute('itemtype').to_s.split(' ').map{|n| uri(n)}.select(&:absolute?).each do |t|
        #   3.1. If type is an absolute URL, generate the following triple:
        type ||= t
        add_triple(item, subject, RDF.type, t)
      end
      
      # 5) If type is an absolute URL, set current name in evaluation context to null.
      ec[:current_name] = nil if type

      # 6) Otherwise, set type to current type from the Evaluation Context if not empty.
      type ||= ec[:current_type]
      add_debug(item)  {"gentrips(6): type=#{type.inspect}"}

      # 7) If the registry contains a URI prefix that is a character for character match of type up to the length of the URI prefix, set vocab as that URI prefix and generate the following triple (unless it has already been generated):
      vocab = Registry.find(type)
      add_debug(item)  {"gentrips(7): vocab=#{vocab.inspect}"}
      add_triple(item, base_uri, USES_VOCAB, RDF::URI(vocab.uri)) if vocab

      # 8) Otherwise, if type is not empty, construct vocab by removing everything following the last
      #    SOLIDUS U+002F ("/") or NUMBER SIGN U+0023 ("#") from the path component of type.
      vocab ||= begin
        type_vocab = type.to_s.sub(/([\/\#])[^\/\#]*$/, '\1')
        add_debug(item)  {"gentrips(8): type_vocab=#{type_vocab.inspect}"}
        Registry.new(type_vocab) # if type
      end

      # 9) Update evaluation context setting current vocabulary to vocab.
      ec[:current_vocabulary] = vocab

      # 10) Set property list to an empty mapping between properties and one or more ordered values as established below.
      property_list = {}

      # 11. For each element _element_ that has one or more property names and is one of the
      #    properties of the item _item_, in the order those elements are given by the algorithm
      #    that returns the properties of an item, run the following substep:
      props = item_properties(item)
      # 11.1. For each name name in element's property names, run the following substeps:
      props.each do |element|
        element.attribute('itemprop').to_s.split(' ').compact.each do |name|
          add_debug(item) {"gentrips(11.1): name=#{name.inspect}, type=#{type}"}
          # 11.1.1) Let context be a copy of evaluation context with current type set to type and current vocabulary set to vocab.
          ec_new = ec.merge({:current_type => type, :current_vocabulary => vocab})
          
          # 11.1.2) Let predicate be the result of generate predicate URI using context and name. Update context by setting current name to predicate.
          predicate = vocab.predicateURI(name, ec_new)
          
          # (Generate Predicate URI steps 6 and 7)
          vocab.expand(predicate) do |statement|
            add_debug(item) {
              "gentrips(11.1.2): expansion #{statement.inspect}"
            }
            @callback.call(statement)
          end

          ec_new[:current_name] = predicate
          add_debug(item) {"gentrips(11.1.2): predicate=#{predicate}"}
          
          # 11.1.3) Let value be the property value of element.
          value = property_value(element)
          add_debug(item) {"gentrips(11.1.3) value=#{value.inspect}"}
          
          # 11.1.4) If value is an item, then generate the triples for value context.
          #         Replace value by the subject returned from those steps.
          if value.is_a?(Hash)
            value = generate_triples(element, ec_new) 
            add_debug(item) {"gentrips(11.1.4): value=#{value.inspect}"}
          end

          # 11.1.5) Add value to property list for predicate
          property_list[predicate] ||= []
          property_list[predicate] << value
        end
      end
      
      # 12) For each predicate in property list
      property_list.each do |predicate, values|
        generatePropertyValues(item, subject, predicate, values)
      end
      
      subject
    end

    def generatePropertyValues(element, subject, predicate, values)
      # If the registry contains a URI prefix that is a character for character match of predicate up to the length
      # of the URI prefix, set vocab as that URI prefix. Otherwise set vocab to null
      registry = Registry.find(predicate)
      add_debug("generatePropertyValues") { "list(#{predicate})? #{registry.as_list(predicate).inspect}"} if registry
      if registry && registry.as_list(predicate)
        value = generateRDFCollection(element, values)
        add_triple(element, subject, predicate, value)
      else
        values.each {|v| add_triple(element, subject, predicate, v)}
      end
    end

    ##
    # Called when values has more than one entry
    # @param [Nokogiri::HTML::Element] element
    # @param [Array<RDF::Value>] values
    # @return [RDF::Node]
    def generateRDFCollection(element, values)
      list = RDF::List.new(nil, nil, values)
      list.each_statement do |st|
        add_triple(element, st.subject, st.predicate, st.object) unless st.object == RDF.List
      end
      list.subject
    end

    ##
    # To find the properties of an item defined by the element root, the user agent must try
    # to crawl the properties of the element root, with an empty list as the value of memory:
    # if this fails, then the properties of the item defined by the element root is an empty
    # list; otherwise, it is the returned list.
    #
    # @param [Nokogiri::XML::Element] item
    # @return [Array<Nokogiri::XML::Element>]
    #   List of property elements for an item
    def item_properties(item)
      add_debug(item, "item_properties")
      results, errors = crawl_properties(item, [])
      raise CrawlFailure, "item_props: errors=#{errors}" if errors > 0
      results
    rescue CrawlFailure => e
      add_error(element, e.message)
      return []
    end
    
    ##
    # To crawl the properties of an element root with a list memory, the user agent must run
    # the following steps. These steps either fail or return a list with a count of errors.
    # The count of errors is used as part of the authoring conformance criteria below.
    #
    # @param [Nokogiri::XML::Element] root
    # @param [Array<Nokokogiri::XML::Element>] memory
    # @return [Array<Array<Nokogiri::XML::Element>, Integer>]
    #   Resultant elements and error count
    def crawl_properties(root, memory)
      
      # 1. If root is in memory, then the algorithm fails; abort these steps.
      raise CrawlFailure, "crawl_props mem already has #{root.inspect}" if memory.include?(root)
      
      # 2. Collect all the elements in the item root; let results be the resulting
      #    list of elements, and errors be the resulting count of errors.
      results, errors = elements_in_item(root)
      add_debug(root) {"crawl_properties results=#{results.map {|e| node_path(e)}.inspect}, errors=#{errors}"}

      # 3. Remove any elements from results that do not have an itemprop attribute specified.
      results = results.select {|e| e.has_attribute?('itemprop')}
      
      # 4. Let new memory be a new list consisting of the old list memory with the addition of root.
      new_memory = memory + [root]
      
      # 5. For each element in results that has an itemscope attribute specified,
      #    crawl the properties of the element, with new memory as the memory.
      results.select {|e| e.has_attribute?('itemscope')}.each do |element|
        begin
          crawl_properties(element, new_memory)
        rescue CrawlFailure => e
          # If this fails, then remove the element from results and increment errors.
          # (If it succeeds, the return value is discarded.)
          memory -= element
          add_error(element, e.message)
          errors += 1
        end
      end
      
      [results, errors]
    end

    ##
    # To collect all the elements in the item root, the user agent must run these steps.
    # They return a list of elements and a count of errors.
    #
    # @param [Nokogiri::XML::Element] root
    # @return [Array<Array<Nokogiri::XML::Element>, Integer>]
    #   Resultant elements and error count
    def elements_in_item(root)
      # Let results and pending be empty lists of elements.
      # Let errors be zero.
      results, errors = [], 0
      
      # Add all the children elements of root to pending.
      pending = root.elements
      
      # If root has an itemref attribute, split the value of that itemref attribute on spaces.
      # For each resulting token ID, 
      root.attribute('itemref').to_s.split(' ').each do |id|
        add_debug(root) {"elements_in_item itemref id #{id}"}
        # if there is an element in the home subtree of root with the ID ID,
        # then add the first such element to pending.
        id_elem = find_element_by_id(id)
        pending << id_elem if id_elem
      end
      add_debug(root) {"elements_in_item pending #{pending.inspect}"}

      # Loop: Remove an element from pending and let current be that element.
      while current = pending.shift
        if results.include?(current)
          # If current is already in results, increment errors.
          add_error(current, "elements_in_item: results already includes #{current.inspect}")
          errors += 1
        elsif !current.has_attribute?('itemscope')
          # If current is not already in results and current does not have an itemscope attribute,
          # then: add all the child elements of current to pending.
          pending += current.elements
        end
        
        # If current is not already in results, then: add current to results.
        results << current unless results.include?(current)
      end

      [results, errors]
    end

    ##
    #
    def property_value(element)
      base = element.base || base_uri
      add_debug(element) {"property_value(#{element.name}): base #{base.inspect}"}
      value = case
      when element.has_attribute?('itemscope')
        {}
      when element.name == 'meta'
        RDF::Literal.new(element.attribute('content').to_s, :language => element.language)
      when element.name == 'data'
        RDF::Literal.new(element.attribute('value').to_s, :language => element.language)
      when %w(audio embed iframe img source track video).include?(element.name)
        uri(element.attribute('src'), base)
      when %w(a area link).include?(element.name)
        uri(element.attribute('href'), base)
      when %w(object).include?(element.name)
        uri(element.attribute('data'), base)
      when %w(time).include?(element.name)
        # Lexically scan value and assign appropriate type, otherwise, leave untyped
        v = (element.attribute('datetime') || element.text).to_s
        datatype = %w(Date Time DateTime Duration).map {|t| RDF::Literal.const_get(t)}.detect do |dt|
          v.match(dt::GRAMMAR)
        end || RDF::Literal
        datatype.new(v, :language => element.language)
      else
        RDF::Literal.new(element.inner_text, :language => element.language)
      end
      add_debug(element) {"  #{value.inspect}"}
      value
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