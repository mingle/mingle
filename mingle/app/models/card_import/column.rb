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

  class Column
    attr_reader :index, :name
  
    def initialize(index, name, project)
      @index = index
      @name = name
      @project = project
      @propert_definition = @project.find_property_definition_or_nil(@name) || Null.new
    end
  
    def tree_column?
      @propert_definition.tree_special?
    end
  
    def tree_config
      if tree_column? 
        @propert_definition.tree_configuration
      else
        nil
      end
    
    end
  end

end
