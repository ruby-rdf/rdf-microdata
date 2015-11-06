$:.unshift "."
require 'spec_helper'

# Class for abstract testing of module
class ExpansionTester
  include RDF::Microdata::Expansion
  include RDF::Enumerable

  attr_reader :about, :information, :repo, :action, :result, :options

  def initialize(name)
    @about = @information = name
    @repo = RDF::Repository.new

    super()
  end

  def graph
    @repo
  end

  def each_statement(&block); @repo.each_statement(&block); end

  def add_debug(node, message = "")
    message = message + yield if block_given?
    @trace ||= []
    @trace << "#{node}: #{message}"
    #STDERR.puts "#{node}: #{message}"
  end
  
  def trace; @trace.join("\n"); end
  
  def load(elements)
    result = nil
    elements.each do |context, ttl|
      case context
      when :default
        @action = ttl
        @repo << parse(ttl)
      when :result
        result = ttl
        result = parse(ttl)
      end
    end
    
    result
  end
  
  def parse(ttl)
    RDF::Graph.new << RDF::Turtle::Reader.new(ttl, prefixes: {
      foaf: RDF::URI("http://xmlns.com/foaf/0.1/"),
      owl:  RDF::OWL.to_uri,
      rdf:  RDF.to_uri,
      rdfa: RDF::RDFA.to_uri,
      rdfs: RDF::RDFS.to_uri,
      xsd:  RDF::XSD.to_uri,
      ex:   RDF::URI("http://example.org/vocab#"),
      nil   => "http://example.org/",
    })
  end
end

describe RDF::Microdata::Expansion do

  describe :owl_entailment do
    {
      "empty"   => {
        default: %q(),
        result: %q()
      },
      "simple"   => {
        default: %q(:a a rdfs:Class .),
        result: %q(:a a rdfs:Class .)
      },
      "prp-spo1"   => {
        default: %q(
          <#me> :name "Gregg Kellogg" .
          :name rdfs:subPropertyOf foaf:name .
        ),
        result: %q(
          <#me> :name "Gregg Kellogg"; foaf:name "Gregg Kellogg" .
          :name rdfs:subPropertyOf foaf:name .
        )
      },
      "prp-eqp1"   => {
        default: %q(
          <#me> :name "Gregg Kellogg" .
          :name owl:equivalentProperty foaf:name .
        ),
        result: %q(
          <#me> :name "Gregg Kellogg"; foaf:name "Gregg Kellogg" .
          :name owl:equivalentProperty foaf:name .
        )
      },
      "prp-eqp2"   => {
        default: %q(
          <#me> foaf:name "Gregg Kellogg" .
          :name owl:equivalentProperty foaf:name .
        ),
        result: %q(
          <#me> :name "Gregg Kellogg"; foaf:name "Gregg Kellogg" .
          :name owl:equivalentProperty foaf:name .
        )
      },
    }.each do |test, elements|
      it test do
        mt = ExpansionTester.new(test)
        result = mt.load(elements)
        mt.send(:owl_entailment, mt.repo)
        expect(mt.graph).to be_equivalent_graph(result, mt)
      end
    end
  end

  describe :expand do
    {
      "simple"   => {
        default: %q(<document> rdfa:usesVocabulary ex: .),
        result: %q(<document> rdfa:usesVocabulary ex: .)
      },
      "prp-spo1"   => {
        default: %q(
          <document> rdfa:usesVocabulary ex: .
          <#me> ex:name "Gregg Kellogg" .
          ex:name rdfs:subPropertyOf foaf:name .
        ),
        result: %q(
          <document> rdfa:usesVocabulary ex: .
          <#me> ex:name "Gregg Kellogg";
            foaf:name "Gregg Kellogg" .
          ex:name rdfs:subPropertyOf foaf:name .
        )
      },
      "prp-eqp1"   => {
        default: %q(
          <document> rdfa:usesVocabulary ex: .
          <#me> ex:name "Gregg Kellogg" .
          ex:name owl:equivalentProperty foaf:name .
        ),
        result: %q(
          <document> rdfa:usesVocabulary ex: .
          <#me> ex:name "Gregg Kellogg";
            foaf:name "Gregg Kellogg" .
          ex:name owl:equivalentProperty foaf:name .
        )
      },
      "prp-eqp2"   => {
        default: %q(
          <document> rdfa:usesVocabulary ex: .
          <#me> foaf:name "Gregg Kellogg" .
          ex:name owl:equivalentProperty foaf:name .
        ),
        result: %q(
          <document> rdfa:usesVocabulary ex: .
          <#me> ex:name "Gregg Kellogg";
            foaf:name "Gregg Kellogg" .
          ex:name owl:equivalentProperty foaf:name .
        )
      },
    }.each do |test, elements|
      it test do
        mt = ExpansionTester.new(test)
        result = mt.load(elements)
        vocab = RDF::URI("http://example.org/vocab#")
        graph = RDF::Graph.new
        expect(RDF::Graph).to receive(:new).at_least(1).times.and_return(graph)
        graph = mt.expand
        expect(graph).to be_equivalent_graph(result, mt)
      end
    end
  end
  
  context "with empty graph" do
    it "returns an empty graph" do
      rdfa = %q(<http></http>)
      expect(parse(rdfa)).to be_equivalent_graph("", trace: @debug)
    end
  end
  
  context "with graph not referencing vocabularies" do
    it "returns unexpanded input" do
      rdfa = %(
        <html prefix="doap: http://usefulinc.com/ns/doap#">
          <body about="" typeof="doap:Project">
            <p>Project description for <span property="doap:name">RDF::RDFa</span>.</p>
            <dl>
              <dt>Creator</dt><dd>
                <a href="http://greggkellogg.net/foaf#me"
                   rel="dc:creator">
                   Gregg Kellogg
                </a>
              </dd>
            </dl>
          </body>
        </html>
      )
      ttl = %(
        @prefix doap: <http://usefulinc.com/ns/doap#> .
        @prefix dc:   <http://purl.org/dc/terms/> .

        <> a doap:Project;
          doap:name "RDF::RDFa";
          dc:creator <http://greggkellogg.net/foaf#me> .
      )
      expect(parse(rdfa)).to be_equivalent_graph(ttl, trace: @debug)
    end
  end
  
  def parse(input, options = {})
    @debug = options[:debug] || []
    RDF::Graph.new << RDF::RDFa::Reader.new(input, options.merge(
      debug: @debug, vocab_expansion: true, vocab_repository: nil
    ))
  end
end
