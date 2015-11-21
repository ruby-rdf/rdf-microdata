require 'rdf/isomorphic'
require 'rspec/matchers'
require 'rdf/rdfa'

RSpec::Matchers.define :have_xpath do |xpath, value, trace|
  match do |actual|
    @doc = Nokogiri::HTML.parse(actual)
    return false unless @doc.is_a?(Nokogiri::XML::Document)
    return false unless @doc.root.is_a?(Nokogiri::XML::Element)
    @namespaces = @doc.namespaces.merge("xhtml" => "http://www.w3.org/1999/xhtml", "xml" => "http://www.w3.org/XML/1998/namespace")
    case value
    when false
      @doc.root.at_xpath(xpath, @namespaces).nil?
    when true
      !@doc.root.at_xpath(xpath, @namespaces).nil?
    when Array
      @doc.root.at_xpath(xpath, @namespaces).to_s.split(" ").include?(*value)
    when Regexp
      @doc.root.at_xpath(xpath, @namespaces).to_s =~ value
    else
      @doc.root.at_xpath(xpath, @namespaces).to_s == value
    end
  end
  
  failure_message do |actual|
    msg = "expected that #{xpath.inspect} would be #{value.inspect} in:\n" + actual.to_s
    msg += "was: #{@doc.root.at_xpath(xpath, @namespaces)}"
    msg +=  "\nDebug:#{trace.join("\n")}" if trace
    msg
  end
  
  failure_message_when_negated do |actual|
    msg = "expected that #{xpath.inspect} would not be #{value.inspect} in:\n" + actual.to_s
    msg +=  "\nDebug:#{trace.join("\n")}" if trace
    msg
  end
end
