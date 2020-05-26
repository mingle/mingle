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
  class RenamedPropertyMqlGeneration < MqlGeneration
    
    def initialize(old_name, new_name, acceptor)
      @old_name, @new_name = old_name, new_name
      acceptor.accept(self)
    end  
    
    def visit_column(property_definition)
      columns_mql << renamed_property_name_mql_snippet(property_definition)
    end  
    
    def visit_group_by_column(property_definition)
      group_by_columns_mql << renamed_property_name_mql_snippet(property_definition)
    end  
    
    def visit_order_by_column(property_definition, order, is_default)
      order_by_columns_mql << renamed_property_name_mql_snippet(property_definition) unless is_default
    end  
    
    def visit_aggregate_function(function, property_definition)
      columns_mql << "#{function}(#{renamed_property_name_mql_snippet(property_definition)})"
    end  

    protected
    def translate(acceptor)
      RenamedPropertyMqlGeneration.new(@old_name, @new_name, acceptor).execute
    end
    
    private
    def renamed_property_name_mql_snippet(old_prop_def)
      ((old_prop_def.name.downcase == @old_name.downcase) ? @new_name : old_prop_def.name).as_mql
    end  
  end  
end
