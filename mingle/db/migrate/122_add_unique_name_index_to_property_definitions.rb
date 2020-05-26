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

class M122PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm122_type' # disable single table inheritance
end

class AddUniqueNameIndexToPropertyDefinitions < ActiveRecord::Migration
  
  POSTFIX_SEPERATOR = '_' unless defined?(POSTFIX_SEPERATOR)
  
  def self.up
    results = ActiveRecord::Base.connection.select_all("SELECT project_id, LOWER(name) as name, COUNT(*) as occurrences FROM #{M122PropertyDefinition.quoted_table_name} GROUP BY project_id, LOWER(name)")
    results = results.select { |result| result['occurrences'].to_i > 1 }
    
    results.each do |result|
      duplicates = M122PropertyDefinition.find(:all, :conditions => ["project_id = ? AND LOWER(name) = ?", result['project_id'], result['name']])
      similarly_named_ones = M122PropertyDefinition.find(:all, :conditions => ["project_id = ? AND LOWER(name) LIKE '#{result['name']}#{POSTFIX_SEPERATOR}%'", result['project_id']])
      rename(duplicates, similarly_named_ones.collect(&:name))
      duplicates.each(&:save)
    end
    
    add_index(:property_definitions, [:project_id, :name], :unique => true)
  end
  
  def self.rename(duplicates, similarly_named_ones)
    similarly_named_ones = similarly_named_ones.collect(&:downcase)
    duplicates.each_with_index do |duplicate, index|
      next if index == 0   # first one can keep its name
      new_name = next_available_name(duplicate.name, similarly_named_ones)
      ActiveRecord::Base.logger.info "(Project id #{duplicate.project_id}) Renaming property definition '#{duplicate.name}' (id #{duplicate.id}) to '#{new_name}' because '#{duplicate.name}' is already taken."
      duplicate.name = new_name
      similarly_named_ones << duplicate.name.downcase
    end
  end
  
  def self.next_available_name(name, similarly_named_ones)
    i = 1
    i+=1 while (similarly_named_ones.include?("#{name.downcase}#{POSTFIX_SEPERATOR}#{i}"))
    "#{name}#{POSTFIX_SEPERATOR}#{i}"
  end
  
  def self.down
    remove_index(:property_definitions, [:project_id, :name])
  end
end
