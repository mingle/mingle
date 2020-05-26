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
  class PropertyDefinitionDetector < Visitor
    
    def initialize(acceptor)
      acceptor.accept(self)
    end  
    
    def execute
      usages.uniq
    end
    
    def uses?(property_definition)
      self.execute.include?(property_definition)
    end
    
    def visit_column(property_definition)
      usages << property_definition if property_definition.kind_of?(PropertyDefinition)
    end
    
    def visit_group_by_column(property_definition)
      usages << property_definition if property_definition.kind_of?(PropertyDefinition)
    end
    
    def visit_order_by_column(property_definition, order, is_default)
      usages << property_definition if property_definition.kind_of?(PropertyDefinition) && !is_default
    end
    
    def visit_aggregate_function(function, property_definition)
      usages << property_definition if property_definition.kind_of?(PropertyDefinition)
    end
    
    def visit_comparison_with_column(column1, operator, column2)
      add_property_definition_for(column1)
      add_property_definition_for(column2)
    end
    
    def visit_comparison_with_plv(column, operator, card_query_plv)
      add_property_definition_for(column)
    end
    
    def visit_comparison_with_value(column, operator, value)
      add_property_definition_for(column)
    end
    
    def visit_comparison_with_number(column, operator, value)
      add_property_definition_for(column)
    end
    
    def visit_today_comparison(column, operator, today)
      add_property_definition_for(column)
    end
    
    def visit_this_card_comparison(column, operator, value)
      add_property_definition_for(column)
    end
    
    def visit_this_card_property_comparison(column, operator, this_card_property)
      add_property_definition_for(column)
      usages << this_card_property.property_definition
    end
    
    def visit_and_condition(*conditions)
      conditions.each { |condition| add_property_definition_for(condition) }
    end
    
    def visit_or_condition(*conditions)
      conditions.each { |condition| add_property_definition_for(condition) }
    end
    
    def visit_not_condition(negated_condition)
      add_property_definition_for(negated_condition)
    end
    
    def visit_explicit_in_condition(column, values, options = {})
      add_property_definition_for(column)
    end
    
    def visit_explicit_numbers_in_condition(column, values)
      add_property_definition_for(column)
    end
    
    def visit_implicit_in_condition(column, query)
      add_property_definition_for(column)
    end
    
    def visit_is_null_condition(column)
      add_property_definition_for(column)
    end
    
    def visit_is_current_user_condition(column, current_user_login)
      add_property_definition_for(column)
    end
    
    def usages
      @usages ||= []
    end  
    
    private
    
    def add_property_definition_for(column)
      (usages << (translate(column) || [])).flatten!
    end  

    def translate(acceptor)
      CardQuery::PropertyDefinitionDetector.new(acceptor).execute
    end  
  end  
end
