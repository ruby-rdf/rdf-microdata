$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::Microdata::Format do
  context "should be discover 'microdata'" do
    [
      [:microdata,                                   RDF::Microdata::Format],
      ["etc/foaf.html",                              RDF::Microdata::Format],
      [{:file_name      => "etc/foaf.html"},         RDF::Microdata::Format],
      [{:file_extension => "html"},                  RDF::Microdata::Format],
      [{:content_type   => "text/html"},             RDF::Microdata::Format],
    ].each do |(arg, format)|
      it "returns #{format} for #{arg.inspect}" do
        RDF::Format.for(arg).should == format
      end
    end
  end
end

describe "RDF::Microdata::Reader" do
  describe "discovery" do
    {
      "html" => RDF::Reader.for(:microdata),
      "etc/foaf.html" => RDF::Reader.for("etc/foaf.html"),
      "foaf.html" => RDF::Reader.for(:file_name      => "foaf.html"),
      ".html" => RDF::Reader.for(:file_extension => "html"),
      "application/xhtml+xml" => RDF::Reader.for(:content_type   => "text/html"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        format.should == RDF::Microdata::Reader
      end
    end
  end

  describe :interface do
    before(:each) do
      @sampledoc = %(
        <div itemscope>
         <p>My name is <span itemprop="name">Elizabeth</span>.</p>
        </div>
      )
    end

    it "should yield reader" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Microdata::Reader)
      RDF::Microdata::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end

    it "should return reader" do
      RDF::Microdata::Reader.new(@sampledoc).should be_a(RDF::Microdata::Reader)
    end

    it "should yield statements" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Statement)
      RDF::Microdata::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end

    it "should yield triples" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::URI, RDF::URI, RDF::Node)
      RDF::Microdata::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end

  context :parsing do
    it "parses a simple graph" do
      md = %q(
      <div itemscope itemtype="http://schema.org/Person">
       <p>My name is <span itemprop="name">Gregg Kellogg</span>.</p>
      </div>
      )
      nt = %q(
      <> <http://www.w3.org/1999/xhtml/microdata#item> _:a .
      _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Person> .
      _:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:name> "Gregg Kellogg" .
      )
      parse(md).should be_equivalent_graph(nt, :trace => @debug)
    end
    
    context "values" do
      before :each do 
        @md_ctx = %q(
          <div itemscope itemtype="http://schema.org/Person">
           %s
          </div>
        )
        @nt_ctx = %q(
        <> <http://www.w3.org/1999/xhtml/microdata#item> _:a .
        _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Person> .
        %s
        )
      end

      [
        [
          %q(<p>My name is <span itemprop="name">Gregg Kellogg</span></p>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:name> "Gregg Kellogg" .)
        ],
        [
          %q(<meta itemprop="meta" content="foo"/>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:meta> "foo" .)
        ],
        [
          %q(<audio itemprop="audio" src="foo"></audio>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:audio> <foo> .)
        ],
        [
          %q(<embed itemprop="embed" src="foo"></embed>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:embed> <foo> .)
        ],
        [
          %q(<iframe itemprop="iframe" src="foo"></iframe>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:iframe> <foo> .)
        ],
        [
          %q(<img itemprop="img" src="foo"/>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:img> <foo> .)
        ],
        [
          %q(<source itemprop="source" src="foo"/>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:source> <foo> .)
        ],
        [
          %q(<track itemprop="track" src="foo"/>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:track> <foo> .)
        ],
        [
          %q(<video itemprop="video" src="foo"></video>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:video> <foo> .)
        ],
        [
          %q(<a itemprop="a" href="foo"></a>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:a> <foo> .)
        ],
        [
          %q(<area itemprop="area" href="foo"/>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:area> <foo> .)
        ],
        [
          %q(<link itemprop="link" href="foo"/>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:link> <foo> .)
        ],
        [
          %q(<object itemprop="object" data="foo"/>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:object> <foo> .)
        ],
        #[
        #  %q(<time itemprop="time" datetime="2011-06-28">28 June 2011</time>),
        #  %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:time> "2011-06-28T00:00:00Z"^^<www.w3.org/2001/XMLSchema#dateTime> .)
        #],
        [
          %q(<div itemprop="knows" itemscope><a href="http://manu.sporny.org/">Manu</a></div>),
          %q(_:a <http://www.w3.org/1999/xhtml/microdata#http://schema.org/Person%23:knows> _:b .)
        ],
      ].each do |(md, nt)|
        it "parses #{md}" do
          parse(@md_ctx % md).should be_equivalent_graph(@nt_ctx % nt, :trace => @debug)
        end
      end
    end
  end

  def parse(input, options = {})
    @debug = options[:debug] || []
    graph = options[:graph] || RDF::Graph.new
    RDF::Microdata::Reader.new(input, {:debug => @debug, :validate => true, :canonicalize => false}.merge(options)).each do |statement|
      graph << statement
    end
    graph
  end

end
