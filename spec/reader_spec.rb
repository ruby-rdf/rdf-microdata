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

    it "parses a simple graph" do
      md = %q(<p>My name is <span itemprop="name">Gregg Kellogg</span>.</p>)
      nt = %q(_:a <http://schema.org/name> "Gregg Kellogg" .)
      parse(@md_ctx % md).should be_equivalent_graph(@nt_ctx % nt, :trace => @debug)
    end
    
    context "title" do
      it "generates dc:title for document title" do
        md = %q(
        <html>
         <head>
          <title>Photo gallery</title>
         </head>
        </html>
        )
        nt = %q(<> <http://purl.org/dc/terms/title> "Photo gallery" .)
        parse(md).should be_equivalent_graph(nt, :trace => @debug)
      end
    end
    
    context "a-rel" do
      [
        [
          %q(<a rel="rel" href="foo.html">Foo</a>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#rel> <foo.html> .),
        ],
        [
          %q(<a rel="rel rel2" href="foo.html">Foo</a>),
          %q(
            <> <http://www.w3.org/1999/xhtml/vocab#rel> <foo.html> .
            <> <http://www.w3.org/1999/xhtml/vocab#rel2> <foo.html> .
          ),
        ],
        [
          %q(<a rel="REL" href="foo.html">Foo</a>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#rel> <foo.html> .),
        ],
        [
          %q(<a rel="rel#ler" href="foo.html">Foo</a>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#rel%23ler> <foo.html> .),
        ],
        [
          %q(<a rel="alternate" href="foo.html">Foo</a>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#alternate> <foo.html> .),
        ],
        [
          %q(<a rel="stylesheet" href="foo.html">Foo</a>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#stylesheet> <foo.html> .),
        ],
        [
          %q(<a rel="alternate stylesheet" href="foo.html">Foo</a>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#ALTERNATE-STYLESHEET> <foo.html> .),
        ],
        [
          %q(<a rel="col:on" href="foo.html">Foo</a>),
          %q(<> <col:on> <foo.html> .),
        ],
        [
          %q(<a rel="http://MiXeDcAsE/" href="foo.html">Foo</a>),
          %q(<> <http://MiXeDcAsE/> <foo.html> .),
        ],
        [
          %q(<area rel="rel" href="foo.html"/>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#rel> <foo.html> .),
        ],
        [
          %q(<link rel="rel" href="foo.html"/>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#rel> <foo.html> .),
        ],
      ].each do |(md, nt)|
        it "parses #{md} to #{nt}" do
          parse(md).should be_equivalent_graph(nt, :trace => @debug)
        end
      end
    end
    
    context "meta" do
      [
        [
          %q(<meta name="name" content="Foo"/>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#name> "Foo" .),
        ],
        [
          %q(<meta name="NAME" content="Foo"/>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#name> "Foo" .),
        ],
        [
          %q(<meta name="name#foo" content="Foo"/>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#name%23foo> "Foo" .),
        ],
        [
          %q(<meta xml:lang="en" name="name#foo" content="Foo"/>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#name%23foo> "Foo"@en .),
        ],
        [
          %q(<meta lang="en" name="name#foo" content="Foo"/>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#name%23foo> "Foo"@en .),
        ],
        [
          %q(<div lang="en"><meta name="name#foo" content="Foo"/></div>),
          %q(<> <http://www.w3.org/1999/xhtml/vocab#name%23foo> "Foo"@en .),
        ],
        [
          %q(<meta name="col:on" content="Foo"/>),
          %q(<> <col:on> "Foo" .),
        ],
      ].each do |(md, nt)|
        it "parses #{md} to #{nt}" do
          parse(md).should be_equivalent_graph(nt, :trace => @debug)
        end
      end
    end
    
    context "blockquote" do
      [
        [
          %q(<blockquote cite="cite.html">Foo</blockquote>),
          %q(<> <http://purl.org/dc/terms/source> <cite.html> .),
        ],
        [
          %q(<q cite="cite.html">Foo</q>),
          %q(<> <http://purl.org/dc/terms/source> <cite.html> .),
        ],
      ].each do |(md, nt)|
        it "parses #{md} to #{nt}" do
          parse(md).should be_equivalent_graph(nt, :trace => @debug)
        end
      end
    end

    context "values" do
      [
        [
          %q(<p>My name is <span itemprop="name">Gregg Kellogg</span></p>),
          %q(_:a <http://schema.org/name> "Gregg Kellogg" .)
        ],
        [
          %q(
          <p>My name is <span itemprop="name">Gregg</span></p>
          <p>My name is <span itemprop="name">Kellogg</span></p>
          ),
          %q(_:a <http://schema.org/name> "Gregg", "Kellogg" .)
        ],
        [
          %q(<p>My name is <span itemprop="name fullName">Gregg Kellogg</span></p>),
          %q(
            _:a <http://schema.org/name> "Gregg Kellogg" .
            _:a <http://schema.org/fullName> "Gregg Kellogg" .
          )
        ],
        [
          %q(<p>My name is <span itemprop="http://schema.org/name">Gregg Kellogg</span></p>),
          %q(_:a <http://schema.org/name> "Gregg Kellogg" .)
        ],
        [
          %q(<meta itemprop="meta" content="foo"/>),
          %q(_:a <http://schema.org/meta> "foo" .)
        ],
        [
          %q(<audio itemprop="audio" src="foo"></audio>),
          %q(_:a <http://schema.org/audio> <foo> .)
        ],
        [
          %q(<embed itemprop="embed" src="foo"></embed>),
          %q(_:a <http://schema.org/embed> <foo> .)
        ],
        [
          %q(<iframe itemprop="iframe" src="foo"></iframe>),
          %q(_:a <http://schema.org/iframe> <foo> .)
        ],
        [
          %q(<img itemprop="img" src="foo"/>),
          %q(_:a <http://schema.org/img> <foo> .)
        ],
        [
          %q(<source itemprop="source" src="foo"/>),
          %q(_:a <http://schema.org/source> <foo> .)
        ],
        [
          %q(<track itemprop="track" src="foo"/>),
          %q(_:a <http://schema.org/track> <foo> .)
        ],
        [
          %q(<video itemprop="video" src="foo"></video>),
          %q(_:a <http://schema.org/video> <foo> .)
        ],
        [
          %q(<a itemprop="a" href="foo"></a>),
          %q(_:a <http://schema.org/a> <foo> .)
        ],
        [
          %q(<area itemprop="area" href="foo"/>),
          %q(_:a <http://schema.org/area> <foo> .)
        ],
        [
          %q(<link itemprop="link" href="foo"/>),
          %q(_:a <http://schema.org/link> <foo> .)
        ],
        [
          %q(<object itemprop="object" data="foo"/>),
          %q(_:a <http://schema.org/object> <foo> .)
        ],
        #[
        #  %q(<time itemprop="time" datetime="2011-06-28">28 June 2011</time>),
        #  %q(_:a <http://schema.org/time> "2011-06-28T00:00:00Z"^^<www.w3.org/2001/XMLSchema#dateTime> .)
        #],
        [
          %q(<div itemprop="knows" itemscope><a href="http://manu.sporny.org/">Manu</a></div>),
          %q(_:a <http://schema.org/knows> _:b .)
        ],
      ].each do |(md, nt)|
        it "parses #{md}" do
          parse(@md_ctx % md).should be_equivalent_graph(@nt_ctx % nt, :trace => @debug)
        end
      end
    end

    context "itemid" do
      before :each do 
        @md_ctx = %q(
          <div itemid="subj" itemscope itemtype="http://schema.org/Person">
           %s
          </div>
        )
        @nt_ctx = %q(
        <> <http://www.w3.org/1999/xhtml/microdata#item> <subj> .
        <subj> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Person> .
        %s
        )
      end

      [
        [
          %q(<p>My name is <span itemprop="name">Gregg Kellogg</span></p>),
          %q(<subj> <http://schema.org/name> "Gregg Kellogg" .)
        ],
        [
          %q(<meta itemprop="meta" content="foo"/>),
          %q(<subj> <http://schema.org/meta> "foo" .)
        ],
        [
          %q(<audio itemprop="audio" src="foo"></audio>),
          %q(<subj> <http://schema.org/audio> <foo> .)
        ],
        [
          %q(<embed itemprop="embed" src="foo"></embed>),
          %q(<subj> <http://schema.org/embed> <foo> .)
        ],
        [
          %q(<iframe itemprop="iframe" src="foo"></iframe>),
          %q(<subj> <http://schema.org/iframe> <foo> .)
        ],
        [
          %q(<img itemprop="img" src="foo"/>),
          %q(<subj> <http://schema.org/img> <foo> .)
        ],
        [
          %q(<source itemprop="source" src="foo"/>),
          %q(<subj> <http://schema.org/source> <foo> .)
        ],
        [
          %q(<track itemprop="track" src="foo"/>),
          %q(<subj> <http://schema.org/track> <foo> .)
        ],
        [
          %q(<video itemprop="video" src="foo"></video>),
          %q(<subj> <http://schema.org/video> <foo> .)
        ],
        [
          %q(<a itemprop="a" href="foo"></a>),
          %q(<subj> <http://schema.org/a> <foo> .)
        ],
        [
          %q(<area itemprop="area" href="foo"/>),
          %q(<subj> <http://schema.org/area> <foo> .)
        ],
        [
          %q(<link itemprop="link" href="foo"/>),
          %q(<subj> <http://schema.org/link> <foo> .)
        ],
        [
          %q(<object itemprop="object" data="foo"/>),
          %q(<subj> <http://schema.org/object> <foo> .)
        ],
        #[
        #  %q(<time itemprop="time" datetime="2011-06-28">28 June 2011</time>),
        #  %q(_:a <http://schema.org/time> "2011-06-28T00:00:00Z"^^<www.w3.org/2001/XMLSchema#dateTime> .)
        #],
        [
          %q(<div itemprop="knows" itemscope itemid="obj"><a href="http://manu.sporny.org/">Manu</a></div>),
          %q(<subj> <http://schema.org/knows> <obj> .)
        ],
      ].each do |(md, nt)|
        it "parses #{md}" do
          parse(@md_ctx % md).should be_equivalent_graph(@nt_ctx % nt, :trace => @debug)
        end
      end
    end
    
    context "itemref" do
      {
        "to single id" =>
        [
          %q(
            <div>
              <div itemscope itemtype="http://schema.org/Person" id="amanda" itemref="a"></div>
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
            </div>
          ),
          %q(
            <> <http://www.w3.org/1999/xhtml/microdata#item>
              [ a <http://schema.org/Person> ;
                <http://schema.org/name> "Amanda" ;
              ]
          )
        ],
        "to multiple ids" =>
        [
          %q(
            <div>
              <div itemscope itemtype="http://schema.org/Person" id="amanda" itemref="a b"></div>
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              <p id="b" itemprop="band">Jazz Band</p>
            </div>
          ),
          %q(
            <> <http://www.w3.org/1999/xhtml/microdata#item>
              [ a <http://schema.org/Person> ;
                <http://schema.org/name> "Amanda" ;
                <http://schema.org/band> "Jazz Band" ;
              ]
          )
        ],
        "with chaining" =>
        [
          %q(
            <div>
              <div itemscope itemtype="http://schema.org/Person" id="amanda" itemref="a b"></div>
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              <div id="b" itemprop="band" itemscope itemtype="http://schema.org/MusicGroup" itemref="c"></div>
              <div id="c">
               <p>Band: <span itemprop="name">Jazz Band</span></p>
               <p>Size: <span itemprop="size">12</span> players</p>
              </div>
            </div>
          ),
          %q(
            <> <http://www.w3.org/1999/xhtml/microdata#item>
              [ a <http://schema.org/Person> ;
                <http://schema.org/name> "Amanda" ;
                <http://schema.org/band> [
                  a <http://schema.org/MusicGroup> ;
                  <http://schema.org/name> "Jazz Band";
                  <http://schema.org/size> "12"
                ]
              ]
          )
        ],
      }.each do |name, (md, nt)|
        it "parses #{name}" do
          parse(md).should be_equivalent_graph(nt, :trace => @debug)
        end
      end
    end
    
    context "test-files" do
      Dir.glob(File.join(File.expand_path(File.dirname(__FILE__)), "test-files", "*.html")).each do |md|
        it "parses #{md}" do
          test_file(md)
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

  def test_file(filepath)
    @graph = parse(File.open(filepath))

    ttl_string = File.read(filepath.sub('.html', '.ttl'))
    @graph.should be_equivalent_graph(ttl_string,
      :trace => @debug)
  end
end
