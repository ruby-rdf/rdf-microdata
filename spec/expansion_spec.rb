$:.unshift "."
require 'spec_helper'

# Class for abstract testing of module
class ExpansionTester
  include RDF::Microdata::Expansion
  include RDF::Enumerable
  include RDF::Util::Logger

  attr_reader :id, :repo, :action, :result, :options
  attr_accessor :format

  def initialize(name)
    @id = name
    @repo = RDF::Repository.new
    @options = {logger: RDF::Spec.logger}

    super()
  end

  def graph
    @repo
  end

  def each_statement(&block); @repo.each_statement(&block); end
  
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
    RDF::Graph.new << RDF::Turtle::Reader.new(ttl,
      logger: false,
      prefixes: {
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
  let(:logger) {RDF::Spec.logger}

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
end
