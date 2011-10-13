### 0.2.2
* Remove non @item* processing
* Sync to HTML Data TF version of spec: https://dvcs.w3.org/hg/htmldata/raw-file/24af1cde0da1/microdata-rdf/index.html
### 0.2.2
* RDF.rb 0.3.4 compatibility.
* Added format detection.

### 0.2.1
* Fixed support for using the document base-uri to resolve relative URIs.

### 0.2.0
* There is no longer any official way to generate RDF and use gem as an experimentation platform.
* Use rdf_term-type property generation and remove option to set it.
* Don't generate triple for html>head>title
* @datetime values are scanned lexically to find appropriate datatype

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
