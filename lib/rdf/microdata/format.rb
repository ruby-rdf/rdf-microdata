# Attempt to load RDF::RDFa first, so that RDF::Format.for(:rdfa) is defined
begin
  require 'rdf/rdfa'
rescue LoadError
  # Soft error
end

module RDF::Microdata
  ##
  # Microdata format specification.
  #
  # @example Obtaining a Microdata format class
  #   RDF::Format.for(:microdata)         #=> RDF::Microdata::Format
  #   RDF::Format.for("etc/foaf.html")
  #   RDF::Format.for(:file_name      => "etc/foaf.html")
  #   RDF::Format.for(file_extension: "html")
  #   RDF::Format.for(:content_type   => "text/html")
  #
  # @example Obtaining serialization format MIME types
  #   RDF::Format.content_types      #=> {"text/html" => [RDF::Microdata::Format]}
  #
  # @see http://www.w3.org/TR/rdf-testcases/#ntriples
  class Format < RDF::Format
    content_encoding 'utf-8'

    # Only define content type if RDFa is not available.
    # The Microdata processor will be launched from there
    # otherwise.
    content_type     'text/html;q=0.5', extension: :html unless RDF::Format.for(:rdfa)
    reader { RDF::Microdata::Reader }
  
    ##
    # Sample detection to see if it matches Microdata (not RDF/XML or RDFa)
    #
    # Use a text sample to detect the format of an input file. Sub-classes implement
    # a matcher sufficient to detect probably format matches, including disambiguating
    # between other similar formats.
    #
    # @param [String] sample Beginning several bytes (~ 1K) of input.
    # @return [Boolean]
    def self.detect(sample)
      !!sample.match(/<[^>]*(itemprop|itemtype|itemref|itemscope|itemid)[^>]*>/m)
    end
  end
end
