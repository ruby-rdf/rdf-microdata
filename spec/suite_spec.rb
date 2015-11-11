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
            t.logger = ::RDF::Spec.logger
            t.logger.info t.inspect
            t.logger.info "source:\n#{t.input}"

            reader = RDF::Microdata::Reader.open(t.action,
              base_uri:        t.action,
              strict:          true,
              validate:        t.negative_test?,
              registry:        t.registry,
              vocab_expansion: t.vocab_expansion,
              logger:          t.logger,
            )
            expect(reader).to be_a RDF::Reader
            graph = RDF::Repository.new

            if t.positive_test?
              begin
                graph << reader
              rescue Exception => e
                expect(e.message).to produce("Not exception #{e.inspect}\n#{e.backtrace.join("\n")}", t.logger)
              end
              if t.evaluate?
                output_graph = RDF::Graph.load(t.result, base_uri: t.action)
                expect(graph).to be_equivalent_graph(output_graph, t)
              else
                expect(graph).to be_a(RDF::Enumerable)
              end
            else
              expect {
                graph << reader
                expect(graph.dump(:ntriples)).to eql "not this"
              }.to raise_error(RDF::ReaderError)
            end
          end
        end
      end
    end
  end
end unless ENV['CI']  # Skip for continuous integration