require 'nokogiri'  # FIXME: Implement using different modules as in RDF::TriX

module RDF::Microdata
  ##
  # An Microdata parser in Ruby
  #
  # Based on processing rules described here:
  # @see http://dev.w3.org/html5/md/
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class Reader < RDF::Reader
    format Format
    XHTML = "http://www.w3.org/1999/xhtml"
    URL_PROPERTY_ELEMENTS = %w(a area audio embed iframe img link object source track video)
    
    class CrawlFailure < StandardError  #:nodoc:
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

        @doc = case input
        when Nokogiri::HTML::Document, Nokogiri::XML::Document
          input
        else
          # Try to detect charset from input
          options[:encoding] ||= input.charset if input.respond_to?(:charset)
          
          # Otherwise, default is utf-8
          options[:encoding] ||= 'utf-8'

          Nokogiri::HTML.parse(input, @base_uri.to_s, options[:encoding])
        end
        
        if (@doc.nil? || @doc.root.nil?)
          add_error(nil, "Empty document")
          raise RDF::ReaderError, "Empty Document"
        end
        add_warning(nil, "Synax errors:\n#{@doc.errors}", RDF::RDFA.DocumentError) if !@doc.errors.empty? && validate?

        block.call(self) if block_given?
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
      parse_whole_document(@doc, @base_uri)
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
    
    # Figure out the document path, if it is a Nokogiri::XML::Element or Attribute
    def node_path(node)
      "<#{@base_uri}>" + case node
      when Nokogiri::XML::Node then node.display_path
      else node.to_s
      end
    end
    
    # Add debug event to debug array, if specified
    #
    # @param [XML Node, any] node:: XML Node or string for showing context
    # @param [String] message::
    def add_debug(node, message)
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
      add_debug(node, "statement: #{RDF::NTriples.serialize(statement)}")
      @callback.call(statement)
    end

    # Parsing an RDFa document (this is *not* the recursive method)
    def parse_whole_document(doc, base)
      base_el = doc.at_css('html>head>base')
      base = base_el.attribute('href').to_s.split('#').first if base_el
      
      if (base)
        # Strip any fragment from base
        base = base.to_s.split('#').first
        base = @options[:base_uri] = uri(base)
        add_debug(base_el, "parse_whole_doc: base='#{base}'")
      end
      
      ##
      # 1. If the title element is not null, then generate the following triple:
      #
      #   subject:  the document's current address
      #   predicate:  http://purl.org/dc/terms/title
      #   object:  the concatenation of the data of all the child text nodes of the title element,
      #            in tree order, as a plain literal, with the language information set from
      #            the language of the title element, if it is not unknown. 
      doc.css('html>head>title').each do |title|
        lang = title.attribute('language')
        add_triple(title, base, DC.title, title.inner_text)
      end
      
      # 2. For each a, area, and link element in the Document, run these substeps:
      #
      # * If the element does not have a rel attribute, then skip this element.
      # * If the element does not have an href attribute, then skip this element.
      # * If resolving the element's href attribute relative to the element is not successful,
      #   then skip this element.
      doc.css('a, area, link').each do |el|
        rel, href = el.attribute('rel'), el.attribute('href')
        next unless rel && href
        href = uri(href, el.base || base)
        next unless href.absolute?
        
        # Otherwise, split the value of the element's rel attribute on spaces, obtaining list of tokens.
        # Coalesce duplicate tokens in list of tokens.
        tokens = rel.to_s.split(/\s+/).map do |tok|
          # Convert each token in list of tokens that does not contain a U+003A COLON characters (:)
          # to ASCII lowercase.
          tok.lower if tok =~ /:/
        end.uniq

        # If list of tokens contains both the tokens alternate and stylesheet,
        # then remove them both and replace them with the single (uppercase) token
        # ALTERNATE-STYLESHEET.
        if tokens.include('alternate') && tokens.include?('stylesheet')
          tokens = tokens - %w(alternate stylesheet)
          tokens << 'ALTERNATE-STYLESHEET'
        end
        
        tokens.each do |tok|
          if tok =~ /:/
            # For each token token in list of tokens that is an absolute URL, generate the following triple:
            add_triple(el, base, tok, href)
          else
            # For each token token in list of tokens that contains no U+003A COLON characters (:),
            # generate the following triple:
            add_triple(el, base, XHV[tok], href.gsub('#', '%23'))
          end
        end
      end

      # 3. For each meta element in the Document that has a name attribute and a content attribute,
      doc.css('meta[name][content]').each do |el|
        name, content = el.attribute('name'), el.attribute('content')
        name_uri = uri(name, el.base || base)
        add_debug(el, "meta: name=#{name.inspect}")
        if name !~ /:/
          # If the value of the name attribute contains no U+003A COLON characters (:),
          # generate the following triple:
          add_triple(el, base, XHV[name.gsub('#', '%23')], RDF::Literal(content, :language => el.language))
        elsif name_uri.absolute?
          # If the value of the name attribute contains no U+003A COLON characters (:),
          # generate the following triple:
          add_triple(el, base, name_uri, RDF::Literal(content, :language => el.language))
        end
      end

      # 4. For each blockquote and q element in the Document that has a cite attribute that resolves
      #    successfully relative to the element, generate the following triple:
      doc.css('blockquote[cite], q[cite]').each do |el|
        object = uri(el.attribute('cite'), el.base || base)
        add_triple(el, base, RDF::DC.source, object) if object.absolute?
      end


      # 5. Let memory be a mapping of items to subjects, initially empty.
      # 6. For each element that is also a top-level microdata item, run the following steps:
      #    * Generate the triples for the item. Pass a reference to memory as the item/subject list.
      #      Let result be the subject returned.
      #    * Generate the following triple:
      #      subject    the document's current address
      #      predicate  http://www.w3.org/1999/xhtml/microdata#item
      #      object     result 
      memory = {}
      doc.css('[itemscope]').
        select {|el| !el.has_attribute?('itemprop')}.
        each do |el|
          object = generate_triples(el, memory)
          add_triple(el, base, RDF::MD.item, object)
      end

      add_debug(doc, "parse_whole_doc: traversal complete'")
    end

    ##
    # Generate triples for an item
    # @param [RDF::Resource] item
    # @param [Hash{Nokogiri::XML::Element} => RDF::Resource] memory
    # @param [Hash{Symbol => Object}] options
    # @option options [RDF::Resource] :fallback_type
    # @option options [RDF::Resource] :fallback_name
    # @return [RDF::Resource]
    def generate_triples(item, memory, options = {})
      fallback_type = options[:fallback_type]
      fallback_name = options[:fallback_name]

      # 1. If there is an entry for item in memory, then let subject be the subject of that entry.
      #    Otherwise, if item has a global identifier and that global identifier is an absolute URL,
      #    let subject be that global identifier. Otherwise, let subject be a new blank node.
      subject = if memory.include?(item)
        memory[item][:subject]
      elsif item.has_attribute?('itemid')
        memory[item] = {}
        u = uri(item.attribute('itemid'))
        u.absolute? && u
      end || RDF::Node.new

      add_debug(item, "gentrips: subject=#{subject.inspect}")

      # 2. Add a mapping from item to subject in memory, if there isn't one already.
      memory[item][:subject] ||= subject
      
      # 3. If item has an item type and that item type is an absolute URL, let type be that item type.
      #    Otherwise, let type be the empty string.
      type = uri(item.attribute('itemtype'))
      type = "" unless type.absolute?
      
      if type != ''
        add_triple(item, subject, RDF.type, type)
        # 4.2. If type does not contain a U+0023 NUMBER SIGN character (#), then append a # to type.
        type += '#' unless type.to_s.include?('#')
        # 4.3. If type does not have a : after its #, append a : to type.
        type += ':' unless type.to_s.match(/\#:/)
      elsif fallback_type
        type = fallback_type
        # 5.2. If type does not contain a U+0023 NUMBER SIGN character (#), then append a # to type.
        type += '#' unless type.to_s.include?('#')
        # 5.3. If type does not have a : after its #, append a : to type.
        type += ':' unless type.to_s.match(/\#:/)
        # 5.4. If the last character of type is not a :, %20 to type.
        type += '%20' unless type[-1] == ':'
        # 5.5. Append the fragment-escaped value of fallback name to type.
        type += fallback_name.to_s.gsub('#', '%23')
      end

      add_debug(item, "gentrips: type=#{type.inspect}")
      
      # 6. For each element _element_ that has one or more property names and is one of the
      #    properties of the item _item_, in the order those elements are given by the algorithm
      #    that returns the properties of an item, run the following substep:
      props = item_properties(item)

      # 6.1. For each name name in element's property names, run the following substeps:
      props.each do |element|
        element.attribute('itemprop').split(' ').each do |name|
          add_debug(item, "gentrips: name=#{name.inspect}")
          # If type is the empty string and name is not an absolute URL, then abort these substeps.
          name_uri = RDF::URI(name)
          next if type == '' && !name_uri.absolute?

          value = property_value(element)
          if value.is_a?(Hash)
            value = generate_triples(element, memory, :fallback_type => type, :fallback_property => name) 
          end
          
          add_debug(item, "gentrips: value=#{value.inspect}")

          predicate = if name_uri.absolute?
            name_uri
          elsif !name.include?(':')
            s = type
            s += '%20' unless s[-1] == ':'
            s += name.gsub('#', '%23')
            RDF::MD[s.gsub('#', '%23')]
          end
          
          add_triple(element, subject, predicate, value) if predicate
        end
      end
      
      subject
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
      # 3. Remove any elements from results that do not have an itemprop attribute specified.
      results = results.select {|e| e.has_attribute('itemprop')}
      
      # 4. Let new memory be a new list consisting of the old list memory with the addition of root.
      new_memory = memory + [root]
      
      # 5. For each element in results that has an itemscope attribute specified,
      #    crawl the properties of the element, with new memory as the memory.
      results.select {|e| e.has_attribute('itemscope')}.each do |element|
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
        # if there is an element in the home subtree of root with the ID ID,
        # then add the first such element to pending.
        pending << id_elem  if id_elem = root.at_css("#{id}")
        
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
      end
      
      [results, errors]
    end

    ##
    #
    def property_value(element)
      case
      when element.has_attribute?('itemscope')
        {}
      when element.name == 'meta'
        element.attribute('content').to_s
      when %w(audio embed iframe img source track video).include?(element.name)
        uri(element.attribute('src'), element.base)
      when %w(a area link).include?(element.name)
        uri(element.attribute('href'), element.base)
      when %w(object).include?(element.name)
        uri(element.attribute('data'), element.base)
      when %w(time).include?(element.name) && element.has_attribute('datetime')
        RDF::Literal::DateTime.new(element.attribute('datetime'))
      else
        RDF::Literal.new(element.text, :language => element.language)
      end
    end

    # Fixme, what about xml:base relative to element?
    def uri(value, base = nil)
      value = if base
        base = uri(base) unless base.is_a?(RDF::URI)
        base.join(value)
      else
        RDF::URI(value)
      end
      value.validate! if validate?
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
    end
  end
end