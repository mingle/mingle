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
  class ListColumns < DelegateClass(Array)
    
    def initialize(columns)
      columns = columns.to_str if columns.respond_to?(:to_str)
      @columns = columns.kind_of?(Array) ? RoundtripJoinableArray.from_array(columns) : RoundtripJoinableArray.from_str(columns.to_s)
      super(@columns)
    end
    
    def add_column(column)
      self.class.new(self + [column.to_s])
    end
    
    def remove_column(column)
      self.class.new(self.ignore_case_delete(column))
    end
    
    def has_column?(column)
      ignore_case_include?(column)
    end
    
    def rename_column(old_column, new_column)
      self.class.new(collect{|c| (c.ignore_case_equal?(old_column) ? new_column : c)})
    end
  end
end
