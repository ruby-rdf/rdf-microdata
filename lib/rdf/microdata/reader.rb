begin
  raise LoadError, "not with java" if RUBY_PLATFORM == "java"
  require 'nokogiri'
rescue LoadError => e
  :rexml
end
require 'rdf/xsd'

module RDF::Microdata
  ##
  # An Microdata parser in Ruby
  #
  # Based on processing rules, amended with the following:
  # * property generation from tokens now uses the associated @itemtype as the basis for generation
  # * implicit triples are not generated, only those with @item*
  # * @datetime values are scanned lexically to find appropriate datatype
  #
  # @see https://dvcs.w3.org/hg/htmldata/raw-file/24af1cde0da1/microdata-rdf/index.html
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Reader < RDF::Reader
    format Format
    XHTML = "http://www.w3.org/1999/xhtml"
    URL_PROPERTY_ELEMENTS = %w(a area audio embed iframe img link object source track video)
    
    class CrawlFailure < StandardError  #:nodoc:
    end

    # Returns the HTML implementation module for this reader instance.
    #
    # @attr_reader [Module]
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

    ##
    # Initializes the Microdata reader instance.
    #
    # @param  [Nokogiri::HTML::Document, Nokogiri::XML::Document, IO, File, String] input
    #   the input stream to read
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @option options [Symbol] :library (:nokogiri)
    #   One of :nokogiri or :rexml. If nil/unspecified uses :nokogiri if available, :rexml otherwise.
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
    # @option options [Array] :debug
    #   Array to place debug messages
    # @return [reader]
    # @yield  [reader] `self`
    # @yieldparam  [RDF::Reader] reader
    # @yieldreturn [void] ignored
    # @raise [Error]:: Raises RDF::ReaderError if _validate_
    def initialize(input = $stdin, options = {}, &block)
      super do
        @debug = options[:debug]

        @library = case options[:library]
          when nil
            (defined?(::Nokogiri) && RUBY_PLATFORM != 'java') ? :nokogiri : :rexml
          when :nokogiri, :rexml
            options[:library]
          else
            raise ArgumentError.new("expected :rexml or :nokogiri, but got #{options[:library].inspect}")
        end

        require "rdf/microdata/reader/#{@library}"
        @implementation = case @library
          when :nokogiri then Nokogiri
          when :rexml    then REXML
        end
        self.extend(@implementation)

        initialize_html(input, options) rescue raise RDF::ReaderError.new($!.message)

        if (root.nil? && validate?)
          raise RDF::ReaderError, "Empty Document"
        end
        errors = doc_errors.reject {|e| e.to_s =~ /Tag (audio|source|track|video|time) invalid/}
        raise RDF::ReaderError, "Syntax errors:\n#{errors}" if !errors.empty? && validate?

        add_debug(@doc, "library = #{@library}")

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
    # @yield  [statement]
    # @yieldparam [RDF::Statement] statement
    # @return [void]
    def each_statement(&block)
      @callback = block

      # parse
      parse_whole_document(@doc, base_uri)
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
      each_statement do |statement|
        block.call(*statement.to_triple)
      end
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
    # @param [Nokogiri::XML::Node, #to_s] node:: XML Node or string for showing context
    # @param [String] message::
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
    # @param [Nokogiri::XML::Node, any] node:: XML Node or string for showing context
    # @param [URI, BNode] subject:: the subject of the statement
    # @param [URI] predicate:: the predicate of the statement
    # @param [URI, BNode, Literal] object:: the object of the statement
    # @return [Statement]:: Added statement
    # @raise [ReaderError]:: Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_triple(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
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
        :memory       => {},
        :current_type => nil,
      }
      items = []
      # For each element that is also a top-level item run the following algorithm:
      #
      #   1) Generate the triples for an item item, using the evaluation context.
      #      Let result be the (URI reference or blank node) subject returned.
      #   2) Append result to item list.
      getItems.each do |el|
        result = generate_triples(el, ec)
        items << result
      end
      
      # 3) If item list contains multiple values, generate an RDF Collection list from
      #    the ordered list of values. Set value to the value returned from generate an RDF Collection.
      # 4) Otherwise, if item list contains a single value set value to that value.
      value = items.length > 1 ? generateRDFCollection(root, items) : items.first

      # 5) Generate the following triple:
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
      # 1. If there is an entry for item in memory, then let subject be the subject of that entry.
      #    Otherwise, if item has a global identifier and that global identifier is an absolute URL,
      #    let subject be that global identifier. Otherwise, let subject be a new blank node.
      subject = if memory.include?(item.node)
        memory[item.node][:subject]
      elsif item.has_attribute?('itemid')
        uri(item.attribute('itemid'), item.base || base_uri)
      end || RDF::Node.new
      memory[item.node] ||= {}

      add_debug(item) {"gentrips(2): subject=#{subject.inspect}, current_type: #{ec[:current_type]}"}

      # 2. Add a mapping from item to subject in memory, if there isn't one already.
      memory[item.node][:subject] ||= subject
      
      # 3. If the item has an @itemtype attribute, extract the value as type.
      rdf_type = nil
      item.attribute('itemtype').to_s.split(' ').map{|n| uri(n)}.select(&:absolute?).each do |type|
        rdf_type ||= type
        add_triple(item, subject, RDF.type, type)
      end
      
      rdf_type ||= ec[:current_type]
      add_debug(item)  {"gentrips(5): rdf_type=#{rdf_type.inspect}"}

      # 6) Set property list to an empty mapping between properties and one or more ordered values as established below.
      property_list = {}
      
      # 7. For each element _element_ that has one or more property names and is one of the
      #    properties of the item _item_, in the order those elements are given by the algorithm
      #    that returns the properties of an item, run the following substep:
      props = item_properties(item)
      # 7.1. For each name name in element's property names, run the following substeps:
      props.each do |element|
        element.attribute('itemprop').to_s.split(' ').compact.each do |name|
          add_debug(element) {"gentrips(7.1): name=#{name.inspect}"}
          # If name is an absolute URI, set predicate to name as a URI reference
          # If type is not an absolute URL and name is not an absolute URL, then abort these substeps.
          # FIXME: need to fragment-escape name
          predicate = uri(name)
          if !rdf_type && !predicate.absolute?
            predicate = uri(name, item.base || base_uri)
            add_debug(element) {"gentrips(7.1.2): predicate=#{predicate}"}
          else
            predicate = RDF::URI(rdf_type.to_s.sub(/([\/\#])[^\/\#]*$/, '\1' + name)) unless predicate.absolute?
            add_debug(element) {"gentrips(7.1.3): predicate=#{predicate}"}
          end

          # 7.1.4) Let value be the property value of element.
          value = property_value(element)
          add_debug(element) {"gentrips(7.1.4) value=#{value.inspect}"}
          
          # 7.1.5) If value is an item, then generate the triples for value using a copy of evaluation context with
          #       current type set to type. Replace value by the subject returned from those steps.
          if value.is_a?(Hash)
            value = generate_triples(element, ec.merge(:current_type => rdf_type)) 
            add_debug(element) {"gentrips(7.1.5): value=#{value.inspect}"}
          end

          property_list[predicate] ||= []
          property_list[predicate] << value
        end
      end
      
      property_list.each do |predicate, values|
        # 8.1) If entry for predicate in property list contains multiple values, generate an RDF Collection list from
        #      the ordered list of values. Set value to the value returned from generate an RDF Collection.
        # 8.1) Otherwise, if predicate in property list contains a single value set value to that value.
        value = values.length > 1 ? generateRDFCollection(item, values) : values.first

        # Generate a triple relating subject, predicate and value
        add_triple(item, subject, predicate, value)
      end
      
      subject
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
      add_debug(root) {"elements_in_item pending #{pending.map {|e| node_path(e)}.inspect}"}

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
        element.attribute('content').to_s
      when %w(audio embed iframe img source track video).include?(element.name)
        uri(element.attribute('src'), base)
      when %w(a area link).include?(element.name)
        uri(element.attribute('href'), base)
      when %w(object).include?(element.name)
        uri(element.attribute('data'), base)
      when %w(time).include?(element.name) && element.has_attribute?('datetime')
        # Lexically scan value and assign appropriate type, otherwise, leave untyped
        v = element.attribute('datetime').to_s
        datatype = %w(Date Time DateTime Duration).map {|t| RDF::Literal.const_get(t)}.detect do |dt|
          v.match(dt::GRAMMAR)
        end || RDF::Literal
        datatype.new(v)
      else
        RDF::Literal.new(element.text, :language => element.language)
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