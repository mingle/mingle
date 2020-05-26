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

class Formula
  class PropertyDefinitionDetector < Visitor
    
    def initialize(acceptor)
      @directly_related_property_definitions = []
      acceptor.accept(self)
    end
    
    def directly_related_property_definitions
      @directly_related_property_definitions.uniq
    end
    
    def all_related_property_definitions(accumulator=[])
      directly_related_property_definitions.each do |pd|
        unless accumulator.include?(pd)
          accumulator += [pd]
          accumulator += pd.component_property_definitions(accumulator).flatten
        end
      end
      accumulator.uniq
    end
    
    def visit_card_property_value(property_definition)
      @directly_related_property_definitions << property_definition
    end
  end
end

# Adding the following line as it is conflicting with aggregate.rb (model) in cruby and causes undefined methods in card_list_view.rb around Aggregate.valid?(...)
Aggregate 

class Aggregate
  class PropertyDefinitionDetector
    def initialize(assoc_prop_defs)
      @directly_related_property_definitions = assoc_prop_defs
    end
    
    def directly_related_property_definitions
      @directly_related_property_definitions.uniq
    end
    
    def all_related_property_definitions(accumulator=[])
      directly_related_property_definitions.each do |pd|
        unless accumulator.include?(pd)
          accumulator += [pd]
          accumulator += pd.component_property_definitions(accumulator).flatten
        end
      end
      accumulator.uniq
    end
  end
end
