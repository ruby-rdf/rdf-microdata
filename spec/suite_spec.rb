$:.unshift "."
require 'spec_helper'

describe RDF::Microdata::Reader do
  # W3C Microdata Test suite from FIXME
  describe "w3c microdata tests" do
    require 'suite_helper'
    MANIFEST = Fixtures::SuiteTest::BASE + "manifest.jsonld"

    Fixtures::SuiteTest::Manifest.open(MANIFEST).each do |m|
      describe m.comment do
        m.entries.each do |t|
          specify "#{t.name}: #{t.comment}" do
            t.debug = []
            reader = RDF::Microdata::Reader.open(t.action,
              base_uri:        t.action,
              strict:          true,
              validate:        false,
              registry:        t.registry,
              vocab_expansion: t.vocab_expansion,
              debug:           t.debug,
            )
            expect(reader).to be_a RDF::Reader

            graph = RDF::Graph.new << reader

            #puts "parse #{t.query} as #{RDF::Reader.for(t.query)}"
            output_graph = RDF::Graph.load(t.result, :base_uri => t.action)
            puts "result: #{CGI.escapeHTML(graph.dump(:ttl, standard_prefixes: true))}" if ::RDF::Microdata::debug?
            if t.positiveTest
              expect(graph).to be_equivalent_graph(output_graph, t)
            else
              expect(graph).not_to be_equivalent_graph(output_graph, t)
            end
          end
        end
      end
    end
  end
end unless ENV['CI']  # Skip for continuous integration