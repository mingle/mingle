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
  class PropertyValueDetector < Visitor
    attr_writer :usages
    
    def initialize(acceptor)
      acceptor.accept(self)
    end  
    
    def execute
      usages.uniq
    end
    
    def property_definitions_with_values
      props_to_values = {}
      usages.uniq.each do |property_value|
        props_to_values[property_value.property_definition] ||= []
        props_to_values[property_value.property_definition] << property_value
      end
      props_to_values
    end
    
    def uses?(property_definition_name, value)
      property_definition = Project.current.find_property_definition(property_definition_name, :with_hidden => true)
      property_value = PropertyValue.create_from_url_identifier(property_definition, value)
      self.execute.include?(property_value)
    end
    
    def visit_comparison_with_value(column, operator, value)
      add_property_value_for(column.property_definition, value)
    end
    
    def visit_and_condition(*conditions)
      self.usages += conditions.collect { |condition| translate(condition) }.flatten
    end
    alias :visit_or_condition :visit_and_condition
    
    def visit_not_condition(negated_condition)
      self.usages += translate(negated_condition)
    end
    
    def visit_explicit_in_condition(column, values, options = {})
      values.each { |value| add_property_value_for(column.property_definition, value) }
    end
    
    def usages
      @usages ||= []
    end  
        
    private
    
    def add_property_value_for(property_definition, value)
      usages << PropertyValue.create_from_url_identifier(property_definition, value) if property_definition.kind_of?(EnumeratedPropertyDefinition) || property_definition.kind_of?(UserPropertyDefinition)
    end  

    def translate(acceptor)
      CardQuery::PropertyValueDetector.new(acceptor).execute
    end  
  end  
end
