require 'nokogiri'
class Nokogiri::XML::Node
  ##
  # Language, taken recursively from element and ancestors
  def language
    @lang ||= attribute('lang') ||
      attributes["lang"] ||
      attributes["xml:lang"] ||
      (parent && parent.element? && parent.language)
  end
  
  ##
  # Get any xml:base in effect for this element
  def base
    if @base.nil?
      @base = attributes['xml:base'] ||
      (parent && parent.element? && parent.base) ||
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
