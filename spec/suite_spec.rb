$:.unshift "."
require 'spec_helper'

describe RDF::Microdata::Reader do
  # W3C Microdata Test suite from FIXME
  describe "w3c microdata tests" do
    require 'suite_helper'
    MANIFEST = Fixtures::SuiteTest::BASE + "manifest.jsonld"

    {native: :native, RDFa: :rdfa}.each do |w, sym|
      describe w do
        Fixtures::SuiteTest::Manifest.open(MANIFEST) do |m|
          describe m.label do
            m.entries.each do |t|
              specify "#{t.name}: #{t.comment}" do
                t.logger = ::RDF::Spec.logger
                t.logger.info t.inspect
                t.logger.info "source:\n#{t.input}"

                if sym == :rdfa
                  %w(0002 0003 0052 0053 0054 0067).include?(t.name.split.last) && skip("Not valid test for RDFa")
                  %w(0026 0044).include?(t.name.split.last) && skip("Difference in subject for head/body elements")
                  %w(0071 0073 0074).include?(t.name.split.last) && skip("No vocabulary expansion")
                  %w(0075 0078).include?(t.name.split.last) && skip("Differences in number parsing")
                  %w(0081 0082 0084).include?(t.name.split.last) && skip("No @itemprop-reverse")
                  %w(0064).include?(t.name.split.last) && pending("Double use of itemref with different vocabularies")
                end

                reader = RDF::Microdata::Reader.open(t.action,
                  base_uri:        t.action,
                  strict:          true,
                  validate:        t.negative_test?,
                  registry:        t.registry,
                  vocab_expansion: t.vocab_expansion,
                  logger:          t.logger,
                  sym           => true # Invoke appropriate writer
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

                    # Remove any rdfa:usesVocabulary property
                    graph.query(predicate: RDF::RDFA.usesVocabulary) do |st|
                      graph.delete!(st)
                    end
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
    end
  end
end unless ENV['CI']  # Skip for continuous integration