$:.unshift "."
require 'spec_helper'

describe RDF::Microdata::Reader do
  # W3C Microdata Test suite from FIXME
  describe "w3c microdata tests", :ci => ENV['CI'] do
    require 'suite_helper'
    MANIFEST = "http://www.w3.org/TR/microdata-rdf/tests/manifest.jsonld"

    Fixtures::SuiteTest::Manifest.open(MANIFEST).each do |m|
      describe m.comment do
        m.entries.each do |t|
          specify "#{t.name}: #{t.comment}" do
            t.debug = []
            t.debug << "base: #{t.data}"
            reader = RDF::Microdata::Reader.open(t.data,
              :base_uri => t.data,
              :strict => true,
              :validate => true,
              :registry_uri => t.registry,
              :debug => t.debug)
            reader.should be_a RDF::Reader

            graph = RDF::Graph.new << reader

            #puts "parse #{t.query} as #{RDF::Reader.for(t.query)}"
            output_graph = RDF::Graph.load(t.query, :base_uri => t.data)
            puts "result: #{CGI.escapeHTML(graph.dump(:ttl))}" if ::RDF::Microdata::debug?
            if t.result
              graph.should be_equivalent_graph(output_graph, t)
            else
              graph.should_not be_equivalent_graph(output_graph, t)
            end
          end
        end
      end
    end
  end
end