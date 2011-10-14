require 'htmlentities'

module RDF::Microdata
  class Reader < RDF::Reader
    ##
    # REXML implementation of an HTML parser.
    #
    # @see http://www.germane-software.com/software/rexml/
    module REXML
      ##
      # Returns the name of the underlying XML library.
      #
      # @return [Symbol]
      def self.library
        :rexml
      end

      # Proxy class to implement uniform element accessors
      class NodeProxy
        attr_reader :node
        attr_reader :parent

        def initialize(node, parent = nil)
          @node = node
          @parent = parent
        end

        ##
        # Element language
        #
        # From HTML5 [3.2.3.3]
        #   If both the lang attribute in no namespace and the lang attribute in the XML namespace are set
        #   on an element, user agents must use the lang attribute in the XML namespace, and the lang
        #   attribute in no namespace must be ignored for the purposes of determining the element's
        #   language.
        #
        # @return [String]
        def language
          language = case
          when @node.attribute("lang")
            @node.attribute("lang").to_s
          else
            parent && parent.element? && parent.language
          end
        end

        ##
        # Return xml:base on element, if defined
        #
        # @return [String]
        def base
          if @base.nil?
            @base = attributes['xml:base'] ||
            (parent && parent.element? && parent.base) ||
            false
          end

          @base == false ? nil : @base
        end

        def display_path
          @display_path ||= begin
            path = []
            path << parent.display_path if parent
            path << @node.name
            case @node
            when ::REXML::Element   then path.join("/")
            when ::REXML::Attribute then path.join("@")
            else path.join("?")
            end
          end
        end

        ##
        # Return true of all child elements are text
        #
        # @return [Array<:text, :element, :attribute>]
        def text_content?
          @node.children.all? {|c| c.is_a?(::REXML::Text)}
        end

        ##
        # Retrieve XMLNS definitions for this element
        #
        # @return [Hash{String => String}]
        def namespaces
          ns_decls = {}
          @node.attributes.each do |name, attr|
            next unless name =~ /^xmlns(?:\:(.+))?/
            ns_decls[$1] = attr
          end
          ns_decls
        end
        
        ##
        # Children of this node
        #
        # @return [NodeSetProxy]
        def children
          NodeSetProxy.new(@node.children, self)
        end
        
        ##
        # Elements of this node
        #
        # @return [NodeSetProxy]
        def elements
          NodeSetProxy.new(@node.elements, self)
        end

        ##
        # Inner text of an element
        #
        # @see http://apidock.com/ruby/REXML/Element/get_text#743-Get-all-inner-texts
        # @return [String]
        def inner_text
          coder = HTMLEntities.new
          ::REXML::XPath.match(@node,'.//text()').map { |e|
            coder.decode(e)
          }.join
        end

        ##
        # Inner text of an element
        #
        # @see http://apidock.com/ruby/REXML/Element/get_text#743-Get-all-inner-texts
        # @return [String]
        def inner_html
          @node.children.map(&:to_s).join
        end

        ##
        # Node type accessors
        #
        # @return [Boolean]
        def element?
          @node.is_a?(::REXML::Element)
        end
        
        def has_attribute?(attr)
          !!node.attribute(attr)
        end

        ##
        # Proxy for everything else to @node
        def method_missing(method, *args)
          @node.send(method, *args)
        end
      end

      ##
      # NodeSet proxy
      class NodeSetProxy
        attr_reader :node_set
        attr_reader :parent

        def initialize(node_set, parent)
          @node_set = node_set
          @parent = parent
        end

        ##
        # Return a proxy for each child
        #
        # @yield(child)
        # @yieldparam(NodeProxy)
        def each
          @node_set.each do |c|
            yield NodeProxy.new(c, parent)
          end
        end

        ##
        # Return proxy for first element and remove it
        # @return [NodeProxy]
        def shift
          (e = node_set.delete(1)) && NodeProxy.new(e, parent)
        end

        ##
        # Add NodeSetProxys
        # @param [NodeSetProxy, Nokogiri::XML::Node]
        # @return [NodeSetProxy]
        def +(other)
          new_ns = node_set.clone
          other.node_set.each {|n| new_ns << n}
          NodeSetProxy.new(new_ns, parent)
        end

        ##
        # Add a NodeProxy
        # @param [NodeProxy, Nokogiri::XML::Node]
        # @return [NodeSetProxy]
        def <<(elem)
          node_set << (elem.is_a?(NodeProxy) ? elem.node : elem)
          self
        end

        ##
        # Proxy for everything else to @node_set
        def method_missing(method, *args)
          @node_set.send(method, *args)
        end
      end

      ##
      # Initializes the underlying XML library.
      #
      # @param  [Hash{Symbol => Object}] options
      # @return [void]
      def initialize_html(input, options = {})
        require 'rexml/document' unless defined?(::REXML)
        @doc = case input
        when ::REXML::Document
          input
        else
          # Try to detect charset from input
          options[:encoding] ||= input.charset if input.respond_to?(:charset)
          
          # Otherwise, default is utf-8
          options[:encoding] ||= 'utf-8'

          # Set xml:base for the document element, if defined
          @base_uri = base_uri ? base_uri.to_s : nil

          # Only parse as XML, no HTML mode
          doc = ::REXML::Document.new(input.respond_to?(:read) ? input.read : input.to_s)
        end
      end

      # Accessor methods to mask native elements & attributes
      
      ##
      # Return proxy for document root
      def root
        @root ||= NodeProxy.new(@doc.root) if @doc && @doc.root
      end
      
      ##
      # Document errors
      def doc_errors
        []
      end
      
      ##
      # Find value of document base
      #
      # @param [String] base Existing base from URI or :base_uri
      # @return [String]
      def doc_base(base)
        # find if the document has a base element
        base_el = ::REXML::XPath.first(@doc, "/html/head/base") 
        base = base_el.attribute("href").to_s.split("#").first if base_el
        
        base || @base_uri
      end

      ##
      # Based on Microdata element.getItems
      #
      # @see http://www.w3.org/TR/2011/WD-microdata-20110525/#top-level-microdata-items
      def getItems
        ::REXML::XPath.match(@doc, "//[@itemscope]").select {|el| !el.attribute('itemprop')}.map {|n| NodeProxy.new(n)}
      end
      
      ##
      # Look up an element in the document by id
      def find_element_by_id(id)
        (e = ::REXML::XPath.first(@doc, "//[@id='#{id}']")) && NodeProxy.new(e)
      end
    end
  end
end
