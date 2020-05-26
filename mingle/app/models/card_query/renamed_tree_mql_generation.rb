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
  class RenamedTreeMqlGeneration < MqlGeneration
    def initialize(old_name, new_name, acceptor)
      @old_name, @new_name = old_name, new_name
      acceptor.accept(self)
    end  

    def visit_in_tree_condition(tree)
      in_tree(tree.name == @old_name ? @new_name : tree.name)
    end
    
    protected
    def translate(acceptor)
      RenamedTreeMqlGeneration.new(@old_name, @new_name, acceptor).execute
    end
    
    private
    def renamed_property_name_mql_snippet(old_prop_def)
      ((old_prop_def.name.downcase == @old_name.downcase) ? @new_name : old_prop_def.name).as_mql
    end  
  end
end
