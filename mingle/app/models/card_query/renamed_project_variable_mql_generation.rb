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

class CardQuery  
  class RenamedProjectVariableMqlGeneration < MqlGeneration
    
    def initialize(old_name, new_name, acceptor)
      @old_name, @new_name = old_name, new_name
      acceptor.accept(self)
    end  
    
    def visit_comparison_with_plv(column, operator, card_query_plv)
      renamed_plv_snippet = if card_query_plv.display_name == ProjectVariable::display_name(@old_name)
        ProjectVariable::display_name(@new_name)
      else
        card_query_plv.display_name
      end    
      conditions_mql << "#{translate(column)} #{operator.as_mql} #{renamed_plv_snippet}"
    end
    
    def visit_explicit_in_condition(column, values, options = {})
      values = options[:original_values] || values
      values = values.map { |v| v.is_a?(PLV) ? v.display_name : v }
      renamed_mql_snippet = if values.any? { |v| v.downcase == ProjectVariable::display_name(@old_name).downcase }
        index_of_old_value = values.index(values.detect { |v| v.downcase == ProjectVariable::display_name(@old_name).downcase })
        renamed_values = if index_of_old_value == 0
          [ProjectVariable::display_name(quote(@new_name))] + values[1..-1].map { |v| quote(v) }
        else
          values[0..(index_of_old_value-1)].map { |v| quote(v) } + [ProjectVariable::display_name(quote(@new_name))] + values[(index_of_old_value+1)..-1].map { |v| quote(v) }
        end
        "#{translate(column)} IN (#{renamed_values.join(', ')})"
      else
        "#{translate(column)} IN (#{values.join(', ')})"
      end    
      conditions_mql << renamed_mql_snippet
    end
    
    protected
    
    def translate(acceptor)
      RenamedProjectVariableMqlGeneration.new(@old_name, @new_name, acceptor).execute
    end
    
    def quote(string)
      string.include?(' ') ? string.as_mql : string
    end
  end
end
