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


class M119Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
end

class M119Transition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}transitions"
end

class M119Page < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}pages"
end

class RenameDuplicateWikiAndTransitionNames < ActiveRecord::Migration
  
  TRANSITION_POSTFIX_SEPERATOR = '_' unless defined?(TRANSITION_POSTFIX_SEPERATOR)
  PAGE_POSTFIX_SEPERATOR = ' ' unless defined?(PAGE_POSTFIX_SEPERATOR) # it is important that this is not an underscore
  
  def self.up
    # transitions section
    results = ActiveRecord::Base.connection.select_all("SELECT project_id, LOWER(name) as name, COUNT(*) as occurrences FROM #{M119Transition.quoted_table_name} GROUP BY project_id, LOWER(name)")
    results = results.select { |result| result['occurrences'].to_i > 1 }
    
    results.each do |result|
      duplicates = M119Transition.find(:all, :conditions => ["project_id = ? AND LOWER(name) = ?", result['project_id'], result['name']])
      similarly_named_ones = M119Transition.find(:all, :conditions => ["project_id = ? AND LOWER(name) LIKE ?", result['project_id'], "#{result['name']}#{TRANSITION_POSTFIX_SEPERATOR}%"])
      rename(duplicates, similarly_named_ones.collect(&:name), TRANSITION_POSTFIX_SEPERATOR)
      duplicates.each(&:save)
    end
    
    # pages section -- sorry about the duplication, but the release is out today
    results = ActiveRecord::Base.connection.select_all("SELECT project_id, LOWER(name) as name, COUNT(*) as occurrences FROM #{M119Page.quoted_table_name} GROUP BY project_id, LOWER(name)")
    results = results.select { |result| result['occurrences'].to_i > 1 }
    
    results.each do |result|
      duplicates = M119Page.find(:all, :conditions => ["project_id = ? AND LOWER(name) = ?", result['project_id'], result['name']])
      similarly_named_ones = M119Page.find(:all, :conditions => ["project_id = ? AND LOWER(name) LIKE ?", result['project_id'], "#{result['name']}#{PAGE_POSTFIX_SEPERATOR}%"])
      rename(duplicates, similarly_named_ones.collect(&:name), PAGE_POSTFIX_SEPERATOR)
      duplicates.each(&:save)
    end
  end
  
  def self.rename(duplicates, similarly_named_ones, postfix_seperator)
    similarly_named_ones = similarly_named_ones.collect(&:downcase)
    duplicates.each_with_index do |duplicate, index|
      next if index == 0   # first one can keep its name
      duplicate.name = next_available_name(duplicate.name, similarly_named_ones, postfix_seperator)
      similarly_named_ones << duplicate.name.downcase
    end
  end
  
  def self.next_available_name(name, similarly_named_ones, postfix_seperator)
    similarly_named_ones = similarly_named_ones.collect(&:downcase)
    i = 1
    i+=1 while (similarly_named_ones.include?("#{name.downcase}#{postfix_seperator}#{i}"))
    "#{name}#{postfix_seperator}#{i}"
  end
  
end
