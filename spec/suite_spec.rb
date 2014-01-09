$:.unshift "."
require 'spec_helper'

describe RDF::Microdata::Reader do
  # W3C Microdata Test suite from FIXME
  describe "w3c microdata tests" do
    require 'suite_helper'
    MANIFEST = "http://dvcs.w3.org/hg/htmldata/raw-file/default/microdata-rdf/tests/manifest.jsonld"

    Fixtures::SuiteTest::Manifest.open(MANIFEST).each do |m|
      describe m.comment do
        m.entries.each do |t|
          specify "#{t.name}: #{t.comment}", :pending => ("Minor whitespace difference" if t.name == "Test 0041") do
            t.debug = []
            reader = RDF::Microdata::Reader.open(t.data,
              :base_uri => t.data,
              :strict => true,
              :validate => false,
              :registry_uri => t.registry,
              #:library => :nokogiri,
              :debug => t.debug)
            reader.should be_a RDF::Reader

            graph = RDF::Repository.new << reader

            #puts "parse #{t.query} as #{RDF::Reader.for(t.query)}"
            output_graph = RDF::Repository.load(t.result, :base_uri => t.data)
            puts "result: #{CGI.escapeHTML(graph.dump(:ttl))}" if ::RDF::Microdata::debug?
            if t.positiveTest
              graph.should be_equivalent_graph(output_graph, t)
            else
              graph.should_not be_equivalent_graph(output_graph, t)
            end
          end
        end
      end
    end
  end
end unless ENV['CI']  # Skip for continuous integration