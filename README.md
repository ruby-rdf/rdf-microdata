# RDF::Microdata reader/writer

[Microdata][] parser for RDF.rb.

## DESCRIPTION
RDF::Microdata is a Microdata reader for Ruby using the [RDF.rb][RDF.rb] library suite.

## FEATURES
RDF::Microdata parses [Microdata][] into statements or triples.

* Microdata parser.
* Uses Nokogiri for parsing HTML

Install with 'gem install rdf-microdata'

## Usage

### Reading RDF data in the Microdata format

    graph = RDF::Graph.load("etc/foaf.html", :format => :microdata)

## Note
This spec is based on the W3C HTML Data Task Force specification and does not support
GRDDL-type triple generation, such as for html>head>title and <a>
  
## Dependencies
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 0.3.4)
* [RDF::XSD](http://rubygems.org/gems/rdf-xsd) (>= 0.3.4)
* [HTMLEntities](https://rubygems.org/gems/htmlentities) ('>= 4.3.0')
* Soft dependency on [Nokogiri](http://rubygems.org/gems/nokogiri) (>= 1.3.3)

## Documentation
Full documentation available on [Rubydoc.info][Microdata doc]

### Principle Classes
* {RDF::Microdata::Format}
  Asserts :html format, text/html mime-type and .html file extension.
* {RDF::Microdata::Reader}
  * {RDF::RDFa::Reader::Nokogiri}
  * {RDF::RDFa::Reader::REXML}

### Additional vocabularies

## TODO
* Add support for LibXML and REXML bindings, and use the best available
* Consider a SAX-based parser for improved performance

## Resources
* [RDF.rb][RDF.rb]
* [Documentation](http://rdf.rubyforge.org/microdata)
* [History](file:file.History.html)
* [Microdata][]

## Author
* [Gregg Kellogg](http://github.com/gkellogg) - <http://kellogg-assoc.com/>

## Contributing

* Do your best to adhere to the existing coding conventions and idioms.
* Don't use hard tabs, and don't leave trailing whitespace on any line.
* Do document every method you add using [YARD][] annotations. Read the
  [tutorial][YARD-GS] or just look at the existing code for examples.
* Don't touch the `.gemspec`, `VERSION` or `AUTHORS` files. If you need to
  change them, do so on your private branch only.
* Do feel free to add yourself to the `CREDITS` file and the corresponding
  list in the the `README`. Alphabetical order applies.
* Do note that in order for us to merge any non-trivial changes (as a rule
  of thumb, additions larger than about 15 lines of code), we need an
  explicit [public domain dedication][PDD] on record from you.

## License

This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.

## FEEDBACK

* gregg@kellogg-assoc.com
* <http://rubygems.org/rdf-microdata>
* <http://github.com/gkellogg/rdf-microdata>
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

[RDF.rb]:           http://rdf.rubyforge.org/
[YARD]:             http://yardoc.org/
[YARD-GS]:          http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
[PDD]:              http://lists.w3.org/Archives/Public/public-rdf-ruby/2010May/0013.html
[Microdata]:        https://dvcs.w3.org/hg/htmldata/raw-file/24af1cde0da1/microdata-rdf/index.html     "Microdata to RDF"
[Microdata doc]:    http://rubydoc.info/github/gkellogg/rdf-microdata/frames
