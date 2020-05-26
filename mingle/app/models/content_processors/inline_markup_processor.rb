#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

class InlineMarkupProcessor

  class << self

    def is_macro_element?(element)
      class_names = (element["class"] || "").normalize_whitespace
      " #{class_names} ".include?(" macro ")
    end

    def is_mingle_image?(element)
      return false unless element.name.downcase == "img"
      class_names = (element["class"] || "").normalize_whitespace
      " #{class_names} ".include?(" mingle-image ") && element["src"].present?
    end

    def resolved_attachment(path)
      attachment_id = Pathname.new(path).basename.to_s
      if attachment_id =~ /\A\d+\z/
        return Attachment.find_by_id(attachment_id)
      end
      nil
    end

  end

  def initialize(html)
    @html = html
  end

  def process
    doc = ContentParser.parse_with_entity_conversion(@html, Renderable::TEXT_ENTITIES_TO_PRESERVE)
    doc.traverse do |node|
      next unless node.element?

      if self.class.is_macro_element?(node)
        macro_text = node["raw_text"]
        node.replace(Nokogiri::XML::Text.new("{{#{macro_text.to_s.gsub("&", "%26")}}}", node.document))
      end

      if self.class.is_mingle_image?(node)
        if (attachment = self.class.resolved_attachment(node["src"]))
          style = "{#{node['style']}}" unless node['style'].blank?
          node.replace(Nokogiri::XML::Text.new("!#{attachment.file_name}!#{style}", node.document))
        end
      end

    end

    doc.to_xhtml.gsub(Renderable::MacroSubstitution::MATCH) do |match|
      URI.unescape(match.gsub("{", "").gsub("}", ""))
    end
  end

end
