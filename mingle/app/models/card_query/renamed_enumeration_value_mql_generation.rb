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
  class RenamedEnumerationValueMqlGeneration < MqlGeneration
    
    def initialize(property_name, old_value, new_value, acceptor)      
      @property_name, @old_value, @new_value = property_name, old_value, new_value
      acceptor.accept(self)
    end  

    def visit_comparison_with_value(column, operator, value)
      renamed_mql_snippet = if translate(column).delete("'").downcase == @property_name.downcase

        existing_mql = "#{translate(column)} #{operator.as_mql} #{value.to_s.as_mql}"
        mql_for_renamed_mql_value = "#{translate(column)} #{operator.as_mql} #{@old_value.to_s.as_mql}"
        if mql_for_renamed_mql_value.downcase == existing_mql.downcase
          "#{translate(column)} #{operator.as_mql} #{@new_value.to_s.as_mql}"
        else
          existing_mql
        end
      else
        "#{translate(column)} #{operator.as_mql} #{value.to_s.as_mql}"
      end
      conditions_mql << renamed_mql_snippet
    end  
    
    def visit_explicit_in_condition(column, values, options = {})
      renamed_mql_snippet = if translate(column).downcase == @property_name.downcase && values.collect(&:downcase).include?(@old_value.downcase)
        index_of_old_value = values.index(values.detect { |v| v.downcase == @old_value.downcase })
        renamed_values = if index_of_old_value == 0
          [@new_value] + values[1..-1]
        else
          values[0..(index_of_old_value-1)] + [@new_value] + values[(index_of_old_value+1)..-1]
        end
        "#{translate(column)} IN (#{renamed_values.collect(&:as_mql).join(', ')})"
      else
        "#{translate(column)} IN (#{values.collect(&:as_mql).join(', ')})"
      end    
      conditions_mql << renamed_mql_snippet
    end
    
    protected
    def translate(acceptor)
      RenamedEnumerationValueMqlGeneration.new(@property_name, @old_value, @new_value, acceptor).execute
    end
  end  
end
