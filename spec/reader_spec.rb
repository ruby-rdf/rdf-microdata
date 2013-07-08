# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/reader'

describe "RDF::Microdata::Reader" do
  before :each do
    @reader = RDF::Microdata::Reader.new(StringIO.new(""))
  end

  include RDF_Reader

  describe ".for" do
    formats = [
      :microdata,
      'etc/doap.html',
      {:file_name      => 'etc/doap.html'},
      {:file_extension => 'html'},
      {:content_type   => 'text/html'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        RDF::Reader.for(arg).should == RDF::Microdata::Reader
      end
    end
  end

  describe :interface do
    before(:each) do
      @sampledoc = %(
        <div itemscope=''>
         <p>My name is <span itemprop="name">Elizabeth</span>.</p>
        </div>
      )
    end

    it "should yield reader" do
      inner = double("inner")
      inner.should_receive(:called).with(RDF::Microdata::Reader)
      RDF::Microdata::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end

    it "should return reader" do
      RDF::Microdata::Reader.new(@sampledoc).should be_a(RDF::Microdata::Reader)
    end

    it "should yield statements" do
      inner = double("inner")
      inner.should_receive(:called).at_least(1).times.with(RDF::Statement)
      RDF::Microdata::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end

    it "should yield triples" do
      inner = double("inner")
      inner.should_receive(:called).at_least(1).times
      RDF::Microdata::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end

  [:nokogiri, :rexml].each do |library|
    context library.to_s, :library => library do
      next if library == :nokogiri && RUBY_PLATFORM == 'java'
      before(:all) {@library = library}
      
      context :parsing do
        before :each do 
          @md_ctx = %q(
            <div itemscope='' itemtype="http://schema.org/Person">
             %s
            </div>
          )
          @nt_ctx = %q(
          <> <http://www.w3.org/ns/md#item> (_:a) .
          _:a <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Person> .
          %s
          )
        end

        it "parses a simple graph" do
          md = %q(<p>My name is <span itemprop="name">Gregg Kellogg</span>.</p>)
          nt = %q(_:a <http://schema.org/name> "Gregg Kellogg" .)
          parse(@md_ctx % md).should be_equivalent_graph(@nt_ctx % nt, :trace => @debug)
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
          ].each do |(md, nt)|
            it "parses #{md}" do
              parse(@md_ctx % md).should be_equivalent_graph(@nt_ctx % nt, :trace => @debug)
            end
          end
        end

        context "base_uri" do
          before :each do 
            @md_ctx = %q(
              <div itemscope='' itemtype="http://schema.org/Person">
               %s
              </div>
            )
            @nt_ctx = %q(
            <http://example.com/> <http://www.w3.org/ns/md#item> (_:a) .
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
              parse(@md_ctx % md, :base_uri => 'http://example.com/').should be_equivalent_graph(@nt_ctx % nt, :trace => @debug, :format => :ttl)
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
            <> <http://www.w3.org/ns/md#item> (<subj>) .
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
            [
              %q(<time itemprop="time" datetime="2011-06-28T00:00:00Z">28 June 2011</time>),
              %q(<subj> <http://schema.org/time> "2011-06-28T00:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .)
            ],
            [
              %q(<div itemprop="knows" itemscope='' itemid="obj"><a href="http://manu.sporny.org/">Manu</a></div>),
              %q(<subj> <http://schema.org/knows> <obj> .)
            ],
          ].each do |(md, nt)|
            it "parses #{md}" do
              parse(@md_ctx % md).should be_equivalent_graph(@nt_ctx % nt, :trace => @debug)
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
              %q(
                <> <http://www.w3.org/ns/md#item> ([ <#name> "Amanda" ]) .
              )
            ],
            "with empty type and token property" => [
              %q(
                <div>
                  <div itemscope='' itemtype="">
                  <p id="a">Name: <span itemprop="name">Amanda</span></p>
                  </div>
                </div>
              ),
              %q(
                <> <http://www.w3.org/ns/md#item> ([ <#name> "Amanda" ]) .
              )
            ],
            "with relative type and token property" => [
              %q(
                <div>
                  <div itemscope='' itemtype="Person">
                  <p id="a">Name: <span itemprop="name">Amanda</span></p>
                  </div>
                </div>
              ),
              %q(
                <> <http://www.w3.org/ns/md#item> ([ <#name> "Amanda" ]) .
              )
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
              <> <http://www.w3.org/ns/md#item>
                ([ a <http://schema.org/Person> ;
                  <http://schema.org/name> "Amanda" ;
                ])
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
              <> <http://www.w3.org/ns/md#item>
                ([ a <http://schema.org/Person>, <http://xmlns.com/foaf/0.1/Person> ;
                  <http://schema.org/name> "Amanda" ;
                ])
              )
            ],
            "with no type and URI property" => [
              %q(
                <div>
                  <div itemscope=''>
                  <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
                  </div>
                </div>
              ),
              %q(
                <> <http://www.w3.org/ns/md#item>
                  ([ <http://schema.org/name> "Amanda" ]) .
              )
            ],
            "with empty type and URI property" => [
              %q(
                <div>
                  <div itemscope='' itemtype="">
                  <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
                  </div>
                </div>
              ),
              %q(
              <> <http://www.w3.org/ns/md#item>
                ([ <http://schema.org/name> "Amanda" ]) .
              )
            ],
            "with relative type and URI property" => [
              %q(
                <div>
                  <div itemscope='' itemtype="Person">
                  <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
                  </div>
                </div>
              ),
              %q(
              <> <http://www.w3.org/ns/md#item>
                ([ <http://schema.org/name> "Amanda" ]) .
              )
            ],
            "with single type and URI property" => [
              %q(
                <div>
                  <div itemscope='' itemtype="http://schema.org/Person">
                  <p id="a">Name: <span itemprop="http://schema.org/name">Amanda</span></p>
                  </div>
                </div>
              ),
              %q(
              <> <http://www.w3.org/ns/md#item>
                ([ a <http://schema.org/Person> ;
                  <http://schema.org/name> "Amanda" ;
                ])
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
              <> <http://www.w3.org/ns/md#item>
                ([ a <http://schema.org/Person>, <http://xmlns.com/foaf/0.1/Person> ;
                  <http://schema.org/name> "Amanda" ;
                ])
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
              <> md:item
                ([ a schema:Person ;
                  schema:name "Gregg" ;
                  schema:knows [ schema:name "Jeni" ]
                ])
              )
            ]
          }.each do |name, (md, nt)|
            it "#{name}" do
              parse(md).should be_equivalent_graph(nt, :trace => @debug, :format => :ttl)
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
                <> <http://www.w3.org/ns/md#item>
                  ([ a <http://schema.org/Person> ;
                    <http://schema.org/name> "Amanda" ;
                  ])
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
                <> <http://www.w3.org/ns/md#item>
                  ([ a <http://schema.org/Person> ;
                    <http://schema.org/name> "Gregg", "Kellogg" ;
                  ])
              )
            ],
            "to single id with different types" =>
            [
              %q(
                <div>
                  <div itemscope='' itemtype="http://xmlns.com/foaf/0.1/Person" id="amanda" itemref="a"></div>
                  <div itemscope='' itemtype="http://schema.org/Person" id="amanda" itemref="a"></div>
                  <p id="a">Name: <span itemprop="name">Amanda</span></p>
                </div>
              ),
              %q(
                <> <http://www.w3.org/ns/md#item> (
                  [ a <http://schema.org/Person> ;
                    <http://schema.org/name> "Amanda" ;
                  ]
                  [ a <http://xmlns.com/foaf/0.1/Person> ;
                    <http://xmlns.com/foaf/0.1/name> "Amanda" ;
                  ]
                  )
              )
            ],
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
                <> <http://www.w3.org/ns/md#item>
                  ([ a <http://schema.org/Person> ;
                    <http://schema.org/name> "Amanda" ;
                    <http://schema.org/band> "Jazz Band" ;
                  ])
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
                <> <http://www.w3.org/ns/md#item>
                  ([ a <http://schema.org/Person> ;
                    <http://schema.org/name> "Amanda" ;
                    <http://schema.org/band> [
                      a <http://schema.org/MusicGroup> ;
                      <http://schema.org/name> "Jazz Band";
                      <http://schema.org/size> "12"
                    ]
                  ])
              )
            ],
            "shared" =>
            [
              %q(
                <div>
                  <div itemscope='' itemref="a"></div>
                  <div itemscope='' itemref="a"></div>
                  <div id="a" itemprop="refers-to" itemscope=''>
                    <span itemprop="name">Amanda</span>
                  </div>
                </div>
              ),
              %q(
                <> <http://www.w3.org/ns/md#item> (
                  [ <#refers-to> _:a ]
                  [ <#refers-to> _:a ]
                ) .
                _:a <#name> "Amanda"
              )
          
            ],
          }.each do |name, (md, nt)|
            it "parses #{name}" do
              parse(md).should be_equivalent_graph(nt, :trace => @debug, :format => :ttl)
            end
          end
        end

        context "propertyURI" do
          context "default expansion" do
            {
              "http://foo/bar + baz => http://foo/baz" =>
              [
                %q(
                  <div itemscope='' itemtype='http://foo/bar'>
                    <p itemprop='baz'>FooBar</p>
                  </div>
                ),
                %q(
                  <> <http://www.w3.org/ns/md#item> (
                    [ a <http://foo/bar>; <http://foo/baz> "FooBar" ]
                  ).
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
                  <> <http://www.w3.org/ns/md#item> (
                    [ a <http://foo#bar>; <http://foo#baz> "FooBar" ]
                  ) .
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
                  <> <http://www.w3.org/ns/md#item> (
                    [ a <http://foo#Type>;
                      <http://foo#bar> [ <http://foo#baz> "Baz"]]
                  )
                )
              ],
            }.each do |name, (md, nt)|
              it "expands #{name}" do
                parse(md).should be_equivalent_graph(nt, :trace => @debug, :format => :ttl)
              end
            end
          end

          context "with contextual expansion" do
            {
              "http://contextual.unordered/ + baz => http://www.w3.org/ns/md?type=http://contextual.unordered/&prop=baz" =>
              [
                %q(
                  <div itemscope='' itemtype='http://contextual.unordered/'>
                    <p itemprop='baz'>FooBar</p>
                  </div>
                ),
                %q(
                  <> <http://www.w3.org/ns/md#item> (
                    [ a <http://contextual.unordered/>;
                      <http://www.w3.org/ns/md?type=http://contextual.unordered/&prop=baz> "FooBar" ]
                  ); <http://www.w3.org/ns/rdfa#usesVocabulary> <http://contextual.unordered/> .
                )
              ],
              "http://contextual.unordered/ + bar + baz => http://www.w3.org/ns/md?type=http://contextual.unordered/&prop=bar.baz" =>
              [
                %q(
                  <div itemscope='' itemtype='http://contextual.unordered/'>
                    <p itemscope='' itemprop='bar'><span itemprop='baz'>Baz</span></p>
                  </div>
                ),
                %q(
                  <> <http://www.w3.org/ns/md#item> (
                    [ a <http://contextual.unordered/>;
                      <http://www.w3.org/ns/md?type=http://contextual.unordered/&prop=bar> [
                        <http://www.w3.org/ns/md?type=http://contextual.unordered/&prop=bar.baz> "Baz"]]
                  ); <http://www.w3.org/ns/rdfa#usesVocabulary> <http://contextual.unordered/> .
                )
              ],
            }.each do |name, (md, nt)|
              it "expands #{name}" do
                parse(md).should be_equivalent_graph(nt, :trace => @debug, :format => :ttl)
              end
            end
          end
        end

        context "vocabulary expansion" do
          it "expands if vocab_expansion is true" do
            md = %q(
              <div itemscope='' itemtype='http://expansion/MainType'>
                <link itemprop='subPropertyOf' href='http://expansion/AdditionalType' />
              </div>
            )
            ttl = %q(
              <> <http://www.w3.org/ns/md#item> (
                  [ a <http://expansion/MainType>,
                      <http://expansion/AdditionalType>;
                    <http://expansion/subPropertyOf>
                      <http://expansion/AdditionalType>]
                );
                <http://www.w3.org/ns/rdfa#usesVocabulary>
                  <http://expansion/> .
              <http://expansion/subPropertyOf>
                <http://www.w3.org/2000/01/rdf-schema#subPropertyOf>
                  <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> .
            )

              parse(md, :vocab_expansion => true).should be_equivalent_graph(ttl, :trace => @debug)
          end

          it "expands by default" do
            md = %q(
              <div itemscope='' itemtype='http://expansion/MainType'>
                <link itemprop='subPropertyOf' href='http://expansion/AdditionalType' />
              </div>
            )
            ttl = %q(
              <> <http://www.w3.org/ns/md#item> (
                  [ a <http://expansion/MainType>,
                      <http://expansion/AdditionalType>;
                    <http://expansion/subPropertyOf>
                      <http://expansion/AdditionalType>]
                );
                <http://www.w3.org/ns/rdfa#usesVocabulary>
                  <http://expansion/> .
              <http://expansion/subPropertyOf>
                <http://www.w3.org/2000/01/rdf-schema#subPropertyOf>
                  <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> .
            )

              parse(md).should be_equivalent_graph(ttl, :trace => @debug)
          end

          it "expands equivalentProperty" do
            md = %q(
              <div itemscope='' itemtype='http://expansion/MainType'>
                <link itemprop='equivalentProperty' href='http://expansion/AdditionalType' />
              </div>
            )
            ttl = %q(
              <> <http://www.w3.org/ns/md#item> (
                [ a <http://expansion/MainType>,
                    <http://expansion/AdditionalType>;
                  <http://expansion/equivalentProperty>
                    <http://expansion/MainType>,
                    <http://expansion/AdditionalType>]
              ); <http://www.w3.org/ns/rdfa#usesVocabulary> <http://expansion/> .
              <http://expansion/equivalentProperty>
                <http://www.w3.org/2002/07/owl#equivalentProperty>
                  <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> .
            )

              parse(md, :vocab_expansion => true).should be_equivalent_graph(ttl, :trace => @debug)
          end

          it "does not expand if vocab_expansion is false" do
            md = %q(
              <div itemscope='' itemtype='http://expansion/MainType'>
                <link itemprop='equivalentProperty' href='http://expansion/AdditionalType' />
              </div>
            )
            ttl = %q(
              <> <http://www.w3.org/ns/md#item> (
                [ a <http://expansion/MainType>;
                  <http://expansion/equivalentProperty>
                    <http://expansion/AdditionalType>]
              ); <http://www.w3.org/ns/rdfa#usesVocabulary> <http://expansion/> .
              <http://expansion/equivalentProperty>
                <http://www.w3.org/2002/07/owl#equivalentProperty>
                  <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> .
            )

              parse(md, :vocab_expansion => false).should be_equivalent_graph(ttl, :trace => @debug)
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
    end
  end
  
  def parse(input, options = {})
    @debug = options[:debug] || []
    graph = options[:graph] || RDF::Graph.new
    RDF::Microdata::Reader.new(input, {
        :debug => @debug,
        :validate => false,
        :library => @library,
        :registry_uri => File.expand_path("../test-files/test-registry.json", __FILE__),
        :canonicalize => false}.merge(options)).each do |statement|
      graph << statement
    end
    graph
  end

  def test_file(filepath)
    graph = parse(File.open(filepath), :registry_uri => nil)

    ttl_string = File.read(filepath.sub('.html', '.ttl'))
    graph.should be_equivalent_graph(ttl_string, :trace => @debug, :format => :ttl)
  end
end
