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


class M125TreeConfiguration < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}tree_configurations"
end

class RenameTreesWithNameEqualToNone < ActiveRecord::Migration
  def self.up
    results = M125TreeConfiguration.find(:all, :conditions => ["LOWER(name) = 'none'"])
    
    results.each do |result|
      similarly_named_ones = M125TreeConfiguration.find(:all, :conditions => ["project_id = ? AND LOWER(name) LIKE 'none%'", result.project_id])
      result.name = next_available_name(result.name, similarly_named_ones.collect(&:name), ' ')
      result.save
    end
  end
  
  def self.down
  end
  
  def self.next_available_name(name, similarly_named_ones, postfix_seperator)
    similarly_named_ones = similarly_named_ones.collect(&:downcase)
    i = 1
    i+=1 while (similarly_named_ones.include?("#{name.downcase}#{postfix_seperator}#{i}"))
    "#{name}#{postfix_seperator}#{i}"
  end
  
end
