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

module CardImport 
  
  class Buffer

    attr_accessor :quote_state

    def initialize
      @value = []
      self.quote_state = Quote::Complete.new
    end  

    def <<(char)
      self.tap do
        self.quote_state = self.quote_state.next(current, previous) if char == CardImport::ExcelParser::QUOTE
        @value << char if char != CardImport::ExcelParser::QUOTE || self.quote_state.append_quote?
      end
    end
  
    def current
      return nil if has_value?
      @value.last
    end
  
    def previous
      return nil if has_value?
      @value[-2]
    end
  
    def value
      v = value_without_strip
      v ? v.strip : v
    end
  
    def value_without_strip
      return nil unless has_value?
      result = @value.compact.pack("c#{@value.compact.size}")
      result.blank? ? nil : result
    end
  
    def has_value?
      has_reached_tab_boundary || has_reached_end_of_line || has_reached_end_of_document
    end
  
    def has_reached_end_of_line
      @value.last == CardImport::ExcelParser::LINE && !self.quote_state.pending?
    end
  
    def has_reached_end_of_document
      has_content = !@value.empty?
      has_nil_last_character = @value.last == nil
      has_content && has_nil_last_character
    end  
  
  private  
    def has_reached_tab_boundary
      @value.last == CardImport::ExcelParser::CELL
    end
  
  end  

  module Quote
    class Pending
      def next(current_character, previous_character)
        current_character == CardImport::ExcelParser::QUOTE && previous_character != CardImport::ExcelParser::QUOTE ? EscapePending.new : Complete.new
      end
    
      def append_quote?
        true
      end  

      def pending?
        true
      end
    end
  
    class Complete
      def next(current_character, previous_character)
        Pending.new
      end

      def append_quote?
        true
      end  
    
      def pending?
        false
      end  
    end
  
    class EscapePending
      def next(current_character, previous_character)
        EscapeComplete.new
      end

      def append_quote?
        false
      end  

      def pending?
        true
      end  
    end
  
    class EscapeComplete
      def next(current_character, previous_character)
        Pending.new
      end

      def append_quote?
        true
      end  

      def pending?
        false
      end
    end
  end
end
