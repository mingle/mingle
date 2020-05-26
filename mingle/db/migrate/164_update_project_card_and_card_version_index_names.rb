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

class UpdateProjectCardAndCardVersionIndexNames < ActiveRecord::Migration
  class M164Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  end
  
  def self.up
    if ActiveRecord::Base.table_name_prefix.blank?
      projects = M164Project.find(:all)
    
      projects.each do |project|
        set_table_names(project)
        remove_indexes(Card.table_name) unless Card.table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
        remove_indexes(Card::Version.table_name) unless Card::Version.table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
      end
    
      projects.each do |project|
        set_table_names(project)
        add_card_index unless Card.table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
        add_card_version_index unless Card::Version.table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
      end
    end
  end

  def self.down
  end
  
  def self.set_table_names(project)
    Card.set_table_name("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_cards")
    Card::Version.set_table_name("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_card_versions")
  end

  def self.remove_indexes(table_name)
    connection.indexes(table_name).each do |index|
      connection.remove_index(table_name, :name => index.name)
    end
  end

  def self.add_card_index
    connection.add_index(connection.safe_table_name(Card.table_name), :number, :unique => true)
  end

  def self.add_card_version_index
    card_version_table_name = connection.safe_table_name(Card::Version.table_name)
    connection.add_index(card_version_table_name, :number)
    connection.add_index(card_version_table_name, :version)
    connection.add_index(card_version_table_name, :card_id)
  end

  def self.connection
    M164Project.connection
  end
end
