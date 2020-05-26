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

class UniqueConstrainForUserLoginAndEmail < ActiveRecord::Migration
  
  class M137User < ActiveRecord::Base
    
    POSTFIX_SEPERATOR = '_' unless defined?(POSTFIX_SEPERATOR)

    set_table_name "#{ActiveRecord::Base.table_name_prefix}users"
    
    def self.postfix_duplicated(attribute)
      self.duplicate_values(attribute).each do |dup_value|
        dup_instances = self.find(:all, :conditions => ["LOWER(#{attribute}) = ?", dup_value])
        postfix(dup_instances[1..-1], attribute, similarly_values_for(attribute, dup_value))
        dup_instances.each(&:save)
      end
    end
    
    def self.similarly_values_for(attribute, value)
      users_with_sim_values = self.find(:all, :conditions => ["LOWER(#{attribute}) LIKE '#{value}#{POSTFIX_SEPERATOR}%%'"])
      users_with_sim_values.collect{ |u| u.send(attribute).downcase }
    end

    def self.duplicate_values(attribute)
      results = ActiveRecord::Base.connection.select_all("SELECT LOWER(#{attribute}) as #{attribute}, COUNT(*) as occurrences FROM #{quoted_table_name} GROUP BY LOWER(#{attribute})")
      results = results.select { |result| result['occurrences'].to_i > 1 }
      results.collect{ |r| r[attribute] }
    end
    
    def self.postfix(dup_instances, attribute, similarly_values)
      dup_instances.each do |duplicate|
        new_value = self.next_available_value(duplicate.send(attribute), similarly_values)
        ActiveRecord::Base.logger.info "#{attribute} of user with id #{duplicate.id} is changed from #{duplicate.send(attribute)} to #{new_value} due to the duplication"
        duplicate.send("#{attribute}=", new_value)
        similarly_values << duplicate.send(attribute).downcase
      end
    end

    def self.next_available_value(value, similarly_values)
      i = 1
      i+=1 while (similarly_values.include?("#{value.downcase}#{POSTFIX_SEPERATOR}#{i}"))
      "#{value}#{POSTFIX_SEPERATOR}#{i}"
    end
  end
  
  
  def self.up
    M137User.postfix_duplicated('login')
    add_index(:users, :login, :unique => true)
    
    M137User.postfix_duplicated('email')
    add_index(:users, :email, :unique => true)
  end

  
  def self.down
    remove_index(:users, :login)
    remove_index(:users, :email)
  end
end
