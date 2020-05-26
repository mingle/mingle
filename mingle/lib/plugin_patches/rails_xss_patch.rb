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

# RailsXss

require 'erubis'

module RailsXss
  class Erubis < ::Erubis::Eruby
    def add_postamble(src)
      src << 'replace_mingle_formatting(@output_buffer.to_s).html_safe'
    end
  end
end

module MingleFormatting
  MINGLE_BOLD_MARKER_OPEN = "f53077d10b01a01b118cb519d7a796f67de67d43"
  MINGLE_BOLD_MARKER_CLOSE = "4321b981f34c6cb8e6a74784c908646c083327e9"
  
  MINGLE_ITALIC_MARKER_OPEN = "f02928c6adcfc7dd3dfd99ba1059dc23282df229"
  MINGLE_ITALIC_MARKER_CLOSE = "f6e3713e3a29e2f2f821316e166fd39973220a89"

  MINGLE_LIST_ITEM_MARKER_OPEN = "a382579f0dbd19efb6bf316d540bd722a0ed808e"
  MINGLE_LIST_ITEM_MARKER_CLOSE = "8c1c989e389d1af199b1360d77cd2ad4543d5eaf"

  MINGLE_UNORDERED_LIST_MARKER_OPEN = "82f4fb72c5b57addbdaa012dc26d0da343ba3a33"
  MINGLE_UNORDERED_LIST_MARKER_CLOSE = "d8eae26df14cd88c56897a4ff71d5a4052b4885f"

  MINGLE_LINE_BREAK_MARKER = "7c87180da784cd4b6fa64ebc291716e7c7d3be99"

  MINGLE_FORMATTING = /#{MINGLE_BOLD_MARKER_OPEN}|#{MINGLE_BOLD_MARKER_CLOSE}|#{MINGLE_LIST_ITEM_MARKER_OPEN}|#{MINGLE_LIST_ITEM_MARKER_CLOSE}|#{MINGLE_ITALIC_MARKER_OPEN}|#{MINGLE_ITALIC_MARKER_CLOSE}|#{MINGLE_UNORDERED_LIST_MARKER_OPEN}|#{MINGLE_UNORDERED_LIST_MARKER_CLOSE}|#{MINGLE_LINE_BREAK_MARKER}/
  
  FORMAT_TO_HTML = {
    MINGLE_BOLD_MARKER_OPEN => "<b>",
    MINGLE_BOLD_MARKER_CLOSE => "</b>",
    MINGLE_ITALIC_MARKER_OPEN => "<i>",
    MINGLE_ITALIC_MARKER_CLOSE => "</i>",
    MINGLE_LIST_ITEM_MARKER_OPEN => "<li>",
    MINGLE_LIST_ITEM_MARKER_CLOSE => "</li>",
    MINGLE_UNORDERED_LIST_MARKER_OPEN => "<ul>",
    MINGLE_UNORDERED_LIST_MARKER_CLOSE => "</ul>",
    MINGLE_LINE_BREAK_MARKER => "<br/>"
  }
  
  def replace_mingle_formatting(text)
    ActiveSupport::GsubSafety.unsafe_substitution_retaining_html_safety text do |unsafe_text| 
      unsafe_text.gsub(MINGLE_FORMATTING) { |match| FORMAT_TO_HTML[match] }
    end
  end

  def remove_mingle_formatting(text)
    text.gsub(MINGLE_FORMATTING, '')
  end

  module_function :replace_mingle_formatting
  module_function :remove_mingle_formatting
end

ActionView::Base.send :include, MingleFormatting
ActionController::Base.send :include, MingleFormatting
module ActiveRecord
  class Errors
    include MingleFormatting
    def to_xml_with_removing_mingle_formatting(*args, &block)
      xml = to_xml_without_removing_mingle_formatting(*args, &block)
      remove_mingle_formatting(xml)
    end
    alias_method_chain :to_xml, :removing_mingle_formatting
  end
end
