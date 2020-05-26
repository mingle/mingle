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
  class CardUsageDetector < Visitor
    attr_writer :mql_conditions
    
    def initialize(acceptor)
      acceptor.accept(self)
    end
    
    def execute
      return [] if mql_conditions.empty?
      Card.find_by_sql "SELECT * FROM #{Card.quoted_table_name} WHERE project_id = #{Project.current.id} AND (#{sql_condition})"
    end
    
    def uses?(card)
      self.execute.include?(card)
    end
    
    def uses_any_card?
      !mql_conditions.empty?
    end
    
    def visit_comparison_with_value(column, operator, value)
      return if value.blank?
      is_number_column = column.number_column?
      return unless (column_is_card_type(column) || is_number_column)
      if is_number_column
        self.mql_conditions << "#{Project.connection.quote_column_name('number')} = #{value.as_mql}"
      else
        self.mql_conditions << "#{Project.connection.quote_column_name('name')} = #{MqlSupport.quote_mql_value(value)}"
      end
      
    end
    
    def visit_comparison_with_number(column, operator, value)
      return unless column_is_card_type(column)
      self.mql_conditions << "#{Project.connection.quote_column_name 'number'} = #{value}"
    end
    
    def visit_explicit_in_condition(column, values, options = {})
      values.each { |value| visit_comparison_with_value(column, nil, value) }
    end
    
    def visit_explicit_numbers_in_condition(column, values)
      values.each { |value| visit_comparison_with_number(column, nil, value) }
    end
    
    def visit_and_condition(*conditions)      
      self.mql_conditions += conditions.collect { |condition| translate(condition) }.flatten
    end
    
    def visit_or_condition(*conditions)
      self.mql_conditions += conditions.collect { |condition| translate(condition) }.flatten
    end
    
    def visit_not_condition(negated_condition)
      self.mql_conditions += translate(negated_condition)
    end
    
    def mql_conditions
      @mql_conditions ||= []
    end
    
    def sql_condition
      mql_conditions.join(" OR ")
    end
    
    private
    
    def translate(acceptor)
      self.class.new(acceptor).mql_conditions
    end  
    
    def column_is_card_type(column)
      PropertyType::CardType === column.property_definition.property_type
    end
  end
end
