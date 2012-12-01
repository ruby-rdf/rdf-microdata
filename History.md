### 0.2.5
* If RDFa is loaded, don't assert text/html and :html content-type/extension, as RDFa will call out based on presence of @itemscope

### 0.2.4
* Update contextual case based on LC spec change to use current_name instead of current_type when creating a predicate URI in contextual.
* Add hCard and hCalendar vocabulary definitions.
* Make sure registry_uri is processed for each invocation, allowing it to be passed as a parameter.
* Add --registry argument to script/parse to allow it to be specified.

### 0.2.3
* Update to latest processing rules, including the use of a registry.
* Updated microdata namespace.
* Matcher output in TTL.
* Complete REXML and Nokogori proxies.
* Added etc/registry.json as a copy of the registry used internally.
* Update examples.
* Parse with linkeddata options.
* Use bundler for specs, if installed.
* Always place md:item in a list.
* Don't use nokogiri with jruby.
* Depend on Nokogiri only for development.
* Some examples.
* Progress on separating HTML parsing to Nokogiri and REXML.
* Sync with first HTML Data TF version of spec.
* Recognize @datetime values with lexical form of xsd:duration and generate appropriately typed lite...
* Generate lists for multi-valued properties.
* Remove fallback_name and change fallback_type to current_type
* Simplify generate_triples logic by removing old type and URI munging.

### 0.2.2
* Remove non @item* processing
* Sync to HTML Data TF version of spec: http://dvcs.w3.org/hg/htmldata/raw-file/24af1cde0da1/microdata-rdf/index.html
### 0.2.2
* RDF.rb 0.3.4 compatibility.
* Added format detection.

### 0.2.1
* Fixed support for using the document base-uri to resolve relative URIs.

### 0.2.0
* There is no longer any official way to generate RDF and use gem as an experimentation platform.
* Use rdf_term-type property generation and remove option to set it.
* Don't generate triple for html\>head\>title
* \@datetime values are scanned lexically to find appropriate datatype

### 0.1.3
* Fixed ruby 1.8 regular expression bug.

### 0.1.2
* Added :rdf\_terms option to Reader to generate more RDF-friendly URIs from terms.

### 0.1.1
* Fixed problem generating appropriate property URIs in Ruby 1.8.

### 0.1.0
* Complete parser generates RDF.

### 0.0.1
* Initial release
