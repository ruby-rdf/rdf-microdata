# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe RDF::Microdata::RdfaReader do
  let!(:doap) {File.expand_path("../../etc/doap.html", __FILE__)}
  let!(:doap_nt) {File.expand_path("../../etc/doap.nt", __FILE__)}
  let!(:registry_path) {File.expand_path("../test-files/test-registry.json", __FILE__)}
  before :each do
    @reader = RDF::Microdata::RdfaReader.new(StringIO.new("<html></html>"))
  end

  context :interface do
    subject {%(
      <div itemscope itemtype="http://schema.org/">
       <p>My name is <span itemprop="name">Elizabeth</span>.</p>
      </div>
    )}
    
    it "should yield reader" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Microdata::RdfaReader)
      RDF::Microdata::RdfaReader.new(subject, base_uri: 'http://example/') do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      expect(RDF::Microdata::RdfaReader.new(subject, base_uri: 'http://example/')).to be_a(RDF::Microdata::RdfaReader)
    end
    
    it "should not raise errors" do
      expect {
        RDF::Microdata::RdfaReader.new(subject, validate:  true, base_uri: 'http://example/')
      }.not_to raise_error
    end

    it "should yield statements" do
      inner = double("inner")
      expect(inner).to receive(:called).with(RDF::Statement).at_least(2)
      RDF::Microdata::RdfaReader.new(subject, base_uri: 'http://example/').each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = double("inner")
      expect(inner).to receive(:called).at_least(2)
      RDF::Microdata::RdfaReader.new(subject, base_uri: 'http://example/').each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end

    context "Microdata Reader with :rdfa option" do
      it "returns a RdfaReader instance" do
        r = RDF::Microdata::Reader.new(StringIO.new(""), rdfa:  true)
        expect(r).to be_a(RDF::Microdata::RdfaReader)
      end
    end
  end

  context :parsing do
    before :each do 
      @md_ctx = %q(
        <div itemscope='' itemtype="http://schema.org/Person">
         %s
        </div>
      )
      @nt_ctx = %q(
      _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Person> .
      %s
      )
    end

    it "parses a simple graph" do
      md = %q(<p>My name is <span itemprop="name">Gregg Kellogg</span>.</p>)
      nt = %q(_:a <http://schema.org/name> "Gregg Kellogg" .)
      expect(parse(@md_ctx % md)).to be_equivalent_graph(@nt_ctx % nt, logger: @logger)
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
          %q(<span itemprop="span" content="foo">Bar</span>),
          %q(_:a <http://schema.org/span> "foo" .)
        ],
        [
          %q(<audio itemprop="audio" src="foo"></audio>),
          %q(_:a <http://schema.org/audio> <http://example/foo> .)
        ],
        [
          %q(<embed itemprop="embed" src="foo"></embed>),
          %q(_:a <http://schema.org/embed> <http://example/foo> .)
        ],
        [
          %q(<iframe itemprop="iframe" src="foo"></iframe>),
          %q(_:a <http://schema.org/iframe> <http://example/foo> .)
        ],
        [
          %q(<img itemprop="img" src="foo"/>),
          %q(_:a <http://schema.org/img> <http://example/foo> .)
        ],
        [
          %q(<source itemprop="source" src="foo"/>),
          %q(_:a <http://schema.org/source> <http://example/foo> .)
        ],
        [
          %q(<track itemprop="track" src="foo"/>),
          %q(_:a <http://schema.org/track> <http://example/foo> .)
        ],
        [
          %q(<video itemprop="video" src="foo"></video>),
          %q(_:a <http://schema.org/video> <http://example/foo> .)
        ],
        [
          %q(<a itemprop="a" href="foo"></a>),
          %q(_:a <http://schema.org/a> <http://example/foo> .)
        ],
        [
          %q(<area itemprop="area" href="foo"/>),
          %q(_:a <http://schema.org/area> <http://example/foo> .)
        ],
        [
          %q(<link itemprop="link" href="foo"/>),
          %q(_:a <http://schema.org/link> <http://example/foo> .)
        ],
        [
          %q(<object itemprop="object" data="foo"/>),
          %q(_:a <http://schema.org/object> <http://example/foo> .)
        ],
        [
          %q(<time itemprop="time" datetime="2011-06-28Z">28 June 2011</time>),
          %q(_:a <http://schema.org/time> "2011-06-28Z"^^<http://www.w3.org/2001/XMLSchema#date> .)
        ],
        [
          %q(<time itemprop="time" datetime="00:00:00Z">midnight</time>),
          %q(_:a <http://schema.org/time> "00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#time> .)
        ],
        [
          %q(<time itemprop="time" datetime="2011-06-28T00:00:00Z">28 June 2011 at midnight</time>),
          %q(_:a <http://schema.org/time> "2011-06-28T00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .)
        ],
        [
          %q(<time itemprop="time" datetime="P2011Y06M28DT00H00M00S">2011 years 6 months 28 days</time>),
          %q(_:a <http://schema.org/time> "P2011Y06M28DT00H00M00S"^^<http://www.w3.org/2001/XMLSchema#duration> .)
        ],
        [
          %q(<time itemprop="time" datetime="foo">28 June 2011</time>),
          %q(_:a <http://schema.org/time> "foo" .)
        ],
        [
          %q(<div itemprop="knows" itemscope=''><a href="http://manu.sporny.org/">Manu</a></div>),
          %q(_:a <http://schema.org/knows> _:b .)
        ],
        [
          %q(<data itemprop="data" value="1"/>),
          %q(_:a <http://schema.org/data> "1"^^<http://www.w3.org/2001/XMLSchema#integer> .)
        ],
        [
          %q(<data itemprop="data" value="1.1"/>),
          %q(_:a <http://schema.org/data> "1.1"^^<http://www.w3.org/2001/XMLSchema#double> .)
        ],
        [
          %q(<data itemprop="data" value="1.1e1"/>),
          %q(_:a <http://schema.org/data> "1.1e1"^^<http://www.w3.org/2001/XMLSchema#double> .)
        ],
        [
          %q(<data itemprop="data" value="foo"/>),
          %q(_:a <http://schema.org/data> "foo" .)
        ],
        [
          %q(<data itemprop="data" lang="en" value="foo"/>),
          %q(_:a <http://schema.org/data> "foo" .)
        ],
        [
          %q(<meter itemprop="meter" value="1"/>),
          %q(_:a <http://schema.org/meter> "1"^^<http://www.w3.org/2001/XMLSchema#integer> .)
        ],
        [
          %q(<meter itemprop="meter" value="1.1"/>),
          %q(_:a <http://schema.org/meter> "1.1"^^<http://www.w3.org/2001/XMLSchema#double> .)
        ],
        [
          %q(<meter itemprop="meter" value="1.1e1"/>),
          %q(_:a <http://schema.org/meter> "1.1e1"^^<http://www.w3.org/2001/XMLSchema#double> .)
        ],
        [
          %q(<meter itemprop="meter" value="foo"/>),
          %q(_:a <http://schema.org/meter> "foo" .)
        ],
        [
          %q(<meter itemprop="meter" lang="en" value="foo"/>),
          %q(_:a <http://schema.org/meter> "foo" .)
        ],
      ].each do |(md, nt)|
        it "parses #{md}" do
          pending if [
            '<data itemprop="data" value="1.1"/>',
            '<meter itemprop="meter" value="1.1"/>',
          ].include?(md)
          expect(parse(@md_ctx % md)).to be_equivalent_graph(@nt_ctx % nt, logger: @logger)
        end
      end
    end

    context "base_uri" do
      before :each do 
        @nt_ctx = %q(
        _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Person> .
        %s
        )
      end

      [
        [
          %q(<audio itemprop="audio" src="foo"></audio>),
          %q(_:a <http://schema.org/audio> <http://example.com/foo> .)
        ],
        [
          %q(<embed itemprop="embed" src="foo"></embed>),
          %q(_:a <http://schema.org/embed> <http://example.com/foo> .)
        ],
        [
          %q(<iframe itemprop="iframe" src="foo"></iframe>),
          %q(_:a <http://schema.org/iframe> <http://example.com/foo> .)
        ],
        [
          %q(<img itemprop="img" src="foo"/>),
          %q(_:a <http://schema.org/img> <http://example.com/foo> .)
        ],
        [
          %q(<source itemprop="source" src="foo"/>),
          %q(_:a <http://schema.org/source> <http://example.com/foo> .)
        ],
        [
          %q(<track itemprop="track" src="foo"/>),
          %q(_:a <http://schema.org/track> <http://example.com/foo> .)
        ],
        [
          %q(<video itemprop="video" src="foo"></video>),
          %q(_:a <http://schema.org/video> <http://example.com/foo> .)
        ],
        [
          %q(<a itemprop="a" href="foo"></a>),
          %q(_:a <http://schema.org/a> <http://example.com/foo> .)
        ],
        [
          %q(<area itemprop="area" href="foo"/>),
          %q(_:a <http://schema.org/area> <http://example.com/foo> .)
        ],
        [
          %q(<link itemprop="link" href="foo"/>),
          %q(_:a <http://schema.org/link> <http://example.com/foo> .)
        ],
        [
          %q(<a itemprop="knows" href="scor">Stéphane Corlosquet</a>),
          %q(_:a <http://schema.org/knows> <http://example.com/scor> .)
        ],
      ].each do |(md, nt)|
        it "parses #{md}" do
          expect(parse(@md_ctx % md, base_uri: 'http://example.com/')).to be_equivalent_graph(@nt_ctx % nt, logger: @logger)
        end
      end
    end

    context "itemid" do
      before :each do 
        @md_ctx = %q(
          <div itemid="subj" itemscope='' itemtype="http://schema.org/Person">
           %s
          </div>
        )
        @nt_ctx = %q(
        <http://example/subj> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Person> .
        %s
        )
      end

      [
        [
          %q(<p>My name is <span itemprop="name">Gregg Kellogg</span></p>),
          %q(<http://example/subj> <http://schema.org/name> "Gregg Kellogg" .)
        ],
        [
          %q(<meta itemprop="meta" content="foo"/>),
          %q(<http://example/subj> <http://schema.org/meta> "foo" .)
        ],
        [
          %q(<audio itemprop="audio" src="foo"></audio>),
          %q(<http://example/subj> <http://schema.org/audio> <http://example/foo> .)
        ],
        [
          %q(<embed itemprop="embed" src="foo"></embed>),
          %q(<http://example/subj> <http://schema.org/embed> <http://example/foo> .)
        ],
        [
          %q(<iframe itemprop="iframe" src="foo"></iframe>),
          %q(<http://example/subj> <http://schema.org/iframe> <http://example/foo> .)
        ],
        [
          %q(<img itemprop="img" src="foo"/>),
          %q(<http://example/subj> <http://schema.org/img> <http://example/foo> .)
        ],
        [
          %q(<source itemprop="source" src="foo"/>),
          %q(<http://example/subj> <http://schema.org/source> <http://example/foo> .)
        ],
        [
          %q(<track itemprop="track" src="foo"/>),
          %q(<http://example/subj> <http://schema.org/track> <http://example/foo> .)
        ],
        [
          %q(<video itemprop="video" src="foo"></video>),
          %q(<http://example/subj> <http://schema.org/video> <http://example/foo> .)
        ],
        [
          %q(<a itemprop="a" href="foo"></a>),
          %q(<http://example/subj> <http://schema.org/a> <http://example/foo> .)
        ],
        [
          %q(<area itemprop="area" href="foo"/>),
          %q(<http://example/subj> <http://schema.org/area> <http://example/foo> .)
        ],
        [
          %q(<link itemprop="link" href="foo"/>),
          %q(<http://example/subj> <http://schema.org/link> <http://example/foo> .)
        ],
        [
          %q(<object itemprop="object" data="foo"/>),
          %q(<http://example/subj> <http://schema.org/object> <http://example/foo> .)
        ],
        [
          %q(<time itemprop="time" datetime="2011-06-28T00:00:00Z">28 June 2011</time>),
          %q(<http://example/subj> <http://schema.org/time> "2011-06-28T00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .)
        ],
        [
          %q(<div itemprop="knows" itemscope='' itemid="obj"><a href="http://manu.sporny.org/">Manu</a></div>),
          %q(<http://example/subj> <http://schema.org/knows> <http://example/obj> .)
        ],
      ].each do |(md, nt)|
        it "parses #{md}" do
          expect(parse(@md_ctx % md)).to be_equivalent_graph(@nt_ctx % nt, logger: @logger)
        end
      end
    end

    context "itemtype" do
      {
        "with no type and token property" => [
          %q(
            <div>
              <div itemscope=''>
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              </div>
            </div>
          ),
          %q()
        ],
        "with empty type and token property" => [
          %q(
            <div>
              <div itemscope='' itemtype="">
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              </div>
            </div>
          ),
          %q()
        ],
        "with relative type and token property" => [
          %q(
            <div>
              <div itemscope='' itemtype="Person">
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              </div>
            </div>
          ),
          %q()
        ],
        "with single type and token property" => [
          %q(
            <div>
              <div itemscope='' itemtype="http://schema.org/Person">
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              </div>
            </div>
          ),
          %q(
          [ a <http://schema.org/Person> ;
            <http://schema.org/name> "Amanda" ;
          ] .
          )
        ],
        "with multipe types and token property" => [
          %q(
            <div>
              <div itemscope='' itemtype="http://schema.org/Person http://xmlns.com/foaf/0.1/Person">
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              </div>
            </div>
          ),
          %q(
          [ a <http://schema.org/Person>, <http://xmlns.com/foaf/0.1/Person> ;
            <http://schema.org/name> "Amanda" ;
          ] .
          )
        ],
        #"with no type and URI property" => [
        #  %q(
        #    <div>
        #      <div itemscope=''>
        #      <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
        #      </div>
        #    </div>
        #  ),
        #  %q(
        #    [ <http://schema.org/name> "Amanda" ] .
        #  )
        #],
        #"with empty type and URI property" => [
        #  %q(
        #    <div>
        #      <div itemscope='' itemtype="">
        #      <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
        #      </div>
        #    </div>
        #  ),
        #  %q(
        #  [ <http://schema.org/name> "Amanda" ] .
        #  )
        #],
        #"with relative type and URI property" => [
        #  %q(
        #    <div>
        #      <div itemscope='' itemtype="Person">
        #      <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
        #      </div>
        #    </div>
        #  ),
        #  %q(
        #  [ <http://schema.org/name> "Amanda" ] .
        #  )
        #],
        "with single type and URI property" => [
          %q(
            <div>
              <div itemscope='' itemtype="http://schema.org/Person">
              <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
              </div>
            </div>
          ),
          %q(
          [ a <http://schema.org/Person> ;
            <http://schema.org/name> "Amanda" ;
          ] .
          )
        ],
        "with multipe types and URI property" => [
          %q(
            <div>
              <div itemscope='' itemtype="http://schema.org/Person http://xmlns.com/foaf/0.1/Person">
              <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
              </div>
            </div>
          ),
          %q(
          [ a <http://schema.org/Person>, <http://xmlns.com/foaf/0.1/Person> ;
            <http://schema.org/name> "Amanda" ;
          ] .
          )
        ],
        "with inherited type and token property" => [
          %q(
            <div itemscope=''  itemtype="http://schema.org/Person">
              <p>Name: <span itemprop="name">Gregg</span></p>
              <div itemprop="knows" itemscope="">
                <p id="a">Name: <span itemprop="name">Jeni</span></p>
              </div>
            </div>
          ),
          %q(
          @prefix md: <http://www.w3.org/ns/md#> .
          @prefix schema: <http://schema.org/> .
          [ a schema:Person ;
            schema:name "Gregg" ;
            schema:knows [ schema:name "Jeni" ]
          ] .
          )
        ]
      }.each do |name, (md, nt)|
        it "#{name}" do
          expect(parse(md)).to be_equivalent_graph(nt, logger: @logger)
        end
      end
    end

    context "itemref" do
      {
        "to single id" =>
        [
          %q(
            <div>
              <div itemscope='' itemtype="http://schema.org/Person" id="amanda" itemref="a"></div>
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
            </div>
          ),
          %q(
            [ a <http://schema.org/Person> ;
              <http://schema.org/name> "Amanda" ;
            ] .
          )
        ],
        "to generate listed property values" =>
        [
          %q(
          <div>
            <div itemscope='' itemtype="http://schema.org/Person" itemref="surname">
              <p>My name is <span itemprop="name">Gregg</span></p>
            </div>
            <p id="surname">My name is <span itemprop="name">Kellogg</span></p>
          </div>
          ),
          %q(
            [ a <http://schema.org/Person> ;
              <http://schema.org/name> "Gregg", "Kellogg" ;
            ] .
          )
        ],
        #"to single id with different types" =>
        #[
        #  %q(
        #    <div>
        #      <div itemscope='' itemtype="http://xmlns.com/foaf/0.1/Person" id="amanda" itemref="a"></div>
        #      <div itemscope='' itemtype="http://schema.org/Person" id="amanda" itemref="a"></div>
        #      <p id="a">Name: <span itemprop="name">Amanda</span></p>
        #    </div>
        #  ),
        #  %q(
        #  [ a <http://schema.org/Person> ;
        #    <http://schema.org/name> "Amanda" ;
        #  ] .
        #  [ a <http://xmlns.com/foaf/0.1/Person> ;
        #    <http://xmlns.com/foaf/0.1/name> "Amanda" ;
        #  ] .
        #  )
        #],
        "to multiple ids" =>
        [
          %q(
            <div>
              <div itemscope='' itemtype="http://schema.org/Person" id="amanda" itemref="a b"></div>
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              <p id="b" itemprop="band">Jazz Band</p>
            </div>
          ),
          %q(
            [ a <http://schema.org/Person> ;
              <http://schema.org/name> "Amanda" ;
              <http://schema.org/band> "Jazz Band" ;
            ] .
          )
        ],
        "with chaining" =>
        [
          %q(
            <div>
              <div itemscope='' itemtype="http://schema.org/Person" id="amanda" itemref="a b"></div>
              <p id="a">Name: <span itemprop="name">Amanda</span></p>
              <div id="b" itemprop="band" itemscope='' itemtype="http://schema.org/MusicGroup" itemref="c"></div>
              <div id="c">
               <p>Band: <span itemprop="name">Jazz Band</span></p>
               <p>Size: <span itemprop="size">12</span> players</p>
              </div>
            </div>
          ),
          %q(
            [ a <http://schema.org/Person> ;
              <http://schema.org/name> "Amanda" ;
              <http://schema.org/band> [
                a <http://schema.org/MusicGroup> ;
                <http://schema.org/name> "Jazz Band";
                <http://schema.org/size> "12"
              ]
            ] .
          )
        ],
        "shared" =>
        [
          %q(
            <div>
              <div itemscope='' itemref="a" itemtype="http://schema.org/Person"></div>
              <div itemscope='' itemref="a"itemtype="http://schema.org/Person"></div>
              <div id="a" itemprop="refers-to" itemscope=''>
                <span itemprop="name">Amanda</span>
              </div>
            </div>
          ),
          %q(
            [ a <http://schema.org/Person>; <http://schema.org/refers-to> _:a ] .
            [ a <http://schema.org/Person>; <http://schema.org/refers-to> _:a ] .
            _:a <http://schema.org/name> "Amanda" .
          )
      
        ],
      }.each do |name, (md, nt)|
        it "parses #{name}" do
          pending "Broke in Nokogiri 13.0" if RUBY_VERSION < "2.7"
          expect(parse(md)).to be_equivalent_graph(nt, logger: @logger)
        end
      end

      it "catches infinite recursion", pending: true do
        md = %(
        <!DOCTYPE html>
        <html><body>
        <div itemscope>
          <div id="ref">
            <div itemprop="name">friend1</div>
            <div itemprop="friend" itemscope>
              <div itemprop="name">friend2</div>
              <div itemprop="friend" itemref="ref" itemscope></div>
            </div>
          </div>
        </div>
        </body></html>
        )
        expect {parse(md, validate: true)}.to raise_error(RDF::ReaderError)
        expect(@logger.to_s).to include("itemref recursion")
      end
    end

    context "propertyURI" do
      context "no expansion" do
        {
          "http://foo/bar + baz => http://foo/baz" =>
          [
            %q(
              <div itemscope='' itemtype='http://foo/bar'>
                <p itemprop='baz'>FooBar</p>
              </div>
            ),
            %q(
              [ a <http://foo/bar>; <http://foo/baz> "FooBar" ] .
            )
          ],
          "http://foo#bar + baz => http://foo#baz" =>
          [
            %q(
              <div itemscope='' itemtype='http://foo#bar'>
                <p itemprop='baz'>FooBar</p>
              </div>
            ),
            %q(
              [ a <http://foo#bar>; <http://foo#baz> "FooBar" ] .
            )
          ],
          "http://foo#Type + bar + baz => http://foo#baz" =>
          [
            %q(
              <div itemscope='' itemtype='http://foo#Type'>
                <p itemscope='' itemprop='bar'><span itemprop='baz'>Baz</span></p>
              </div>
            ),
            %q(
              [ a <http://foo#Type>;
                <http://foo#bar> [ <http://foo#baz> "Baz"]] .
            )
          ],
        }.each do |name, (md, nt)|
          it "expands #{name}" do
            expect(parse(md)).to be_equivalent_graph(nt, logger: @logger)
          end
        end
      end

      context "default propertyURI generation" do
        {
          "http://foo/bar + baz => http://foo/baz" =>
          [
            %q(
              <div itemscope='' itemtype='http://foo/bar'>
                <p itemprop='baz'>FooBar</p>
              </div>
            ),
            %q(
              [ a <http://foo/bar>; <http://foo/baz> "FooBar" ] .
            )
          ],
          "http://foo#bar + baz => http://foo#baz" =>
          [
            %q(
              <div itemscope='' itemtype='http://foo#bar'>
                <p itemprop='baz'>FooBar</p>
              </div>
            ),
            %q(
              [ a <http://foo#bar>; <http://foo#baz> "FooBar" ] .
            )
          ],
          "http://foo#Type + bar + baz => http://foo#baz" =>
          [
            %q(
              <div itemscope='' itemtype='http://foo#Type'>
                <p itemscope='' itemprop='bar'><span itemprop='baz'>Baz</span></p>
              </div>
            ),
            %q(
              [ a <http://foo#Type>;
                <http://foo#bar> [ <http://foo#baz> "Baz"]] .
            )
          ],
        }.each do |name, (md, nt)|
          it "expands #{name}" do
            expect(parse(md)).to be_equivalent_graph(nt, logger: @logger)
          end
        end
      end
    end

    context "itemprop-reverse", skip: true do
      {
        "link" => [
          %q(
            <div itemscope itemtype="http://schema.org/Person">
              <span itemprop="name">William Shakespeare</span>
              <link itemprop-reverse="creator" href="http://www.freebase.com/m/0yq9mqd">
            </div>
          ),
          %q(
            <http://www.freebase.com/m/0yq9mqd> <http://schema.org/creator> [
              a <http://schema.org/Person>;
              <http://schema.org/name> "William Shakespeare"
            ] .
          )
        ],
        "itemscope" => [
          %q(
            <div itemscope itemtype="http://schema.org/ShoppingCenter">
              <span itemprop="name">The ACME Shopping Mall on Structured Data Avenue</span>
              <span itemprop="description">The ACME Shopping Mall is your one-stop paradise for all data-related shopping needs, from schemas to instance data</span>
              <p>Here is a list of shops inside:</p>
              <div itemprop-reverse="containedIn" itemscope itemtype="http://schema.org/Restaurant">
                <span itemprop="name">Dan Brickley's Data Restaurant</span>
              </div>
              <div itemprop-reverse="containedIn" itemscope itemtype="http://schema.org/Bakery">
                <span itemprop="name">Ramanathan Guha's Meta Content Framework Bakery</span>
              </div>
            </div>
          ),
          %q(
            _:a a <http://schema.org/ShoppingCenter>;
                <http://schema.org/name> "The ACME Shopping Mall on Structured Data Avenue";
                <http://schema.org/description> "The ACME Shopping Mall is your one-stop paradise for all data-related shopping needs, from schemas to instance data" .
            _:b a <http://schema.org/Restaurant>;
                <http://schema.org/name> "Dan Brickley's Data Restaurant";
                <http://schema.org/containedIn> _:a .
            _:c a <http://schema.org/Bakery>;
                <http://schema.org/name> "Ramanathan Guha's Meta Content Framework Bakery";
                <http://schema.org/containedIn> _:a .
          )
        ],
        "literal" => [
          %q(
            <div itemscope itemtype="http://schema.org/Person">
              <span itemprop="name">William Shakespeare</span>
              <meta itemprop-reverse="creator" content="foo">
            </div>
          ),
          %q(
            _:a a <http://schema.org/Person>;
                <http://schema.org/name> "William Shakespeare" .
          )
        ],
        "itemprop and itemprop-reverse" => [
          %q(
            <div itemscope itemtype="http://schema.org/Organization">
              <span itemprop="name">Cryptography Users</span>
              <div itemprop-reverse="memberOf" itemprop="member" itemscope
                    itemtype="http://schema.org/OrganizationRole">
                <div itemprop-reverse="memberOf" itemprop="member" itemscope
                        itemtype="http://schema.org/Person">
                  <span itemprop="name">Alice</span>
                </div>
                <span itemprop="startDate">1977</span>
              </div>
            </div>
          ),
          %q(
            @prefix schema: <http://schema.org/> .
            @prefix md: <http://www.w3.org/ns/md#> .

            _:a a schema:Organization;
                schema:name "Cryptography Users";
                schema:member _:b .
            _:b a schema:OrganizationRole;
                schema:startDate "1977";
                schema:member _:c;
                schema:memberOf _:a .
            _:c a schema:Person;
                schema:name "Alice";
                schema:memberOf _:b .
          )
        ],
      }.each do |name, (md, nt)|
        it "expands #{name}" do
          expect(parse(md)).to be_equivalent_graph(nt, logger: @logger)
        end
      end
    end

    context "vocabulary expansion", pending: true do
      it "always expands" do
        md = %q(
          <div itemscope='' itemtype='http://schema.org/Person'>
            <link itemprop='additionalType' href='http://xmlns.com/foaf/0.1/Person' />
          </div>
        )
        ttl = %q(
          [ a <http://schema.org/Person>, <http://xmlns.com/foaf/0.1/Person>;
            <http://schema.org/additionalType> <http://xmlns.com/foaf/0.1/Person>
          ] .
        )

        expect(parse(md, vocab_expansion: true)).to be_equivalent_graph(ttl, logger: @logger)
      end

      it "always expands (schemas)" do
        md = %q(
          <div itemscope='' itemtype='https://schema.org/Person'>
            <link itemprop='additionalType' href='http://xmlns.com/foaf/0.1/Person' />
          </div>
        )
        ttl = %q(
          [ a <https://schema.org/Person>, <http://xmlns.com/foaf/0.1/Person>;
            <https://schema.org/additionalType> <http://xmlns.com/foaf/0.1/Person>
          ] .
        )

        expect(parse(md, vocab_expansion: true)).to be_equivalent_graph(ttl, logger: @logger)
      end
    end

    context "test-files", skip: true do
      Dir.glob(File.join(File.expand_path(File.dirname(__FILE__)), "test-files", "*.html")).each do |md|
        it "parses #{md}" do
          test_file(md)
        end
      end
    end
  end
  
  def parse(input, options = {})
    @logger = RDF::Spec.logger
    graph = options[:graph] || RDF::Graph.new
    RDF::Microdata::Reader.new(input,
      logger: @logger,
      rdfa: true,
      validate: false,
      base_uri: "http://example/",
      registry: registry_path,
      canonicalize: false,
      **options
    ).each do |statement|
      graph << statement
    end

    # Remove any rdfa:usesVocabulary statements
    graph.query({predicate: RDF::RDFA.usesVocabulary}).each do |stmt|
      graph.delete(stmt)
    end
    graph
  end

  def test_file(filepath, **options)
    graph = parse(File.open(filepath), **options)

    ttl_string = File.read(filepath.sub('.html', '.ttl'))
    expect(graph).to be_equivalent_graph(ttl_string, logger: @logger)
  end
end
