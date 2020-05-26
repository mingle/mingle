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

class ImageAttachmentProcessor

  def initialize(html)
    @html = html
  end

  def process(&block)
    return nil unless @html
    doc = ContentParser.parse_with_entity_conversion(@html, Renderable::TEXT_ENTITIES_TO_PRESERVE)
    doc.traverse do |node|
      next unless (node.element? && InlineMarkupProcessor.is_mingle_image?(node))

      if (attachment = InlineMarkupProcessor.resolved_attachment(node["src"]))
        block.call node, attachment if block_given?
      end
    end

    doc.to_xhtml
  end

end
