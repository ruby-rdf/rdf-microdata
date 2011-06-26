module RDF::Microdata
  ##
  # Microdata format specification.
  #
  # @example Obtaining a Microdata format class
  #   RDF::Format.for(:microdata)         #=> RDF::Microdata::Format
  #   RDF::Format.for("etc/foaf.html")
  #   RDF::Format.for(:file_name      => "etc/foaf.html")
  #   RDF::Format.for(:file_extension => "html")
  #   RDF::Format.for(:content_type   => "text/html")
  #
  # @example Obtaining serialization format MIME types
  #   RDF::Format.content_types      #=> {"text/html" => [RDF::Microdata::Format]}
  #
  # @see http://www.w3.org/TR/rdf-testcases/#ntriples
  class Format < RDF::Format
    content_encoding 'utf-8'
    content_type     'text/html', :extension => :html
    reader { RDF::Microdata::Reader }
  end
end
