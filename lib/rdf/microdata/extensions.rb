require 'nokogiri'
class Nokogiri::XML::Node
  ##
  # Language, taken recursively from element and ancestors
  def language
    @lang ||= attribute('lang') ||
      attribuite('xml:lang') ||
      attribute('xml:lang', 'xml' => 'http://www.w3.org/XML/1998/namespace') ||
      (parent && parent.language)
  end
  
  ##
  # Get any xml:base in effect for this element
  def base
    if @base.nil?
      @base = attribute('xml:base', 'xml' => 'http://www.w3.org/XML/1998/namespace') ||
      (parent && parent.base) ||
      false
    end
    
    @base == false ? nil : @base
  end

  def display_path
    @display_path ||= case self
    when Nokogiri::XML::Document then ""
    when Nokogiri::XML::Element then parent ? "#{parent.display_path}/#{name}" : name
    when Nokogiri::XML::Attr then "#{parent.display_path}@#{name}"
    end
  end
end

class Nokogiri::XML::Document
end
