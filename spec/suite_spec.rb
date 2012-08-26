$:.unshift "."
require 'spec_helper'

unless env['CI']  # Skip for continuous integration
  describe RDF::Microdata::Reader do
    # W3C Microdata Test suite from FIXME
    describe "w3c microdata tests" do
      require 'suite_helper'

      describe "positive parser tests" do
        Fixtures::SuiteTest::Good.each do |m|
          m.entries.each do |t|
            #puts t.inspect
            specify "#{t.name}: #{t.comment}" do
              t.debug = []
              reader = RDF::Microdata::Reader.new(t.input,
                :base_uri => t.inputDocument,
                :strict => true,
                :validate => true,
                :debug => t.debug)
              reader.should be_a RDF::Reader

              graph = RDF::Graph.new << reader

              #puts "parse #{self.outputDocument} as #{RDF::Reader.for(self.outputDocument)}"
              output_graph = RDF::Graph.load(t.result, :base_uri => t.inputDocument)
              puts "result: #{CGI.escapeHTML(graph.to_ntriples)}" if ::RDF::Microdata::debug?
              graph.should be_equivalent_graph(output_graph, self)
            end
          end
        end
      end

      #describe "negative parser tests" do
      #  Fixtures::SuiteTest::Bad.each do |m|
      #    m.entries.each do |t|
      #      specify "#{t.name}: #{t.comment}" do
      #        begin
      #          t.run_test do
      #            lambda do
      #              #t.debug = []
      #               g = RDF::Graph.new
      #               RDF::Microdata::Reader.new(t.input,
      #                   :base_uri => t.base_uri,
      #                   :validate => true,
      #                   :debug => t.debug).each do |statement|
      #                 g << statement
      #               end
      #            end.should raise_error(RDF::ReaderError)
      #          end
      #        end
      #      end
      #    end
      #  end
      #end
    end

  end
end