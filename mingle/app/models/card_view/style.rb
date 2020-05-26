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

module CardView  
  module Style        
    LIST = List.new
    GRID = Grid.new
    TREE = Tree.new
    HIERARCHY = Hierarchy.new
    TREE_STYLES = [LIST, HIERARCHY, GRID, TREE]
    CLASSIC_STYLES = [LIST, GRID]
    
    def from_str(str, maximized = false)
      [LIST, HIERARCHY, GRID, TREE].detect { |vs| vs.to_s.ignore_case_equal?(str.trim) } || LIST
    end
    
    def require_tree?(style)
      style = from_str(style) if style.is_a?(String)
      [HIERARCHY, TREE].include?(style)
    end
    
    def support_columns?(style)
      [LIST, HIERARCHY].include?(style)
    end
    
    def support_pagination?(style)
      LIST == style
    end
    
    module_function :from_str, :require_tree?, :support_columns?, :support_pagination?
  end
end
