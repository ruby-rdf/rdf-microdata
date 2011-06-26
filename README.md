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

### Reading RDF data in the RDFa format

    graph = RDF::Graph.load("etc/foaf.html", :format => :microdata)

## Dependencies
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 0.3.3)
* [Nokogiri](http://rubygems.org/gems/nokogiri) (>= 1.3.3)

## Documentation
Full documentation available on [RubyForge](http://rdf.rubyforge.org/microdata)

### Principle Classes
* {RDF::Microdata::Format}
  * {RDF::Microdata::HTML}
    Asserts :html format, text/html mime-type and .html file extension.
* {RDF::RDFa::Reader}

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
[Microdata]:        http://www.w3.org/TR/2011/WD-microdata-20110525/     "HTML Microdata"
