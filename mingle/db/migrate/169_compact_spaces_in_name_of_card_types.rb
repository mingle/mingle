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

module M169Utils
  include MigrationHelper
  
  def update_table_column(table, column, old_value, new_value)
    sql = SqlHelper.sanitize_sql("UPDATE #{table} SET #{column} = ? WHERE #{column}= ? ", new_value, old_value)
    ActiveRecord::Base.connection.execute(sql)    
  end

  def tbl(name)
    ActiveRecord::Base.connection.safe_table_name(name)
  end
  module_function :tbl
end

class M169Project < ActiveRecord::Base
  include M169Utils
  
  set_table_name M169Utils.tbl("projects")
  has_many :card_types, :class_name => 'M169CardType', :foreign_key => 'project_id'
    
  def card_table_name
    tbl "#{identifier}_cards"
  end
  
  def card_version_table_name
    tbl "#{identifier}_card_versions"
  end
end

class M169CardType < ActiveRecord::Base
  include M169Utils
  
  set_table_name M169Utils.tbl("card_types")
  belongs_to :project, :class_name => 'M169Project', :foreign_key => 'project_id'
    
  def compact_spaces_in_name
    return unless name =~ /\s{2,}/
    old_name, new_name = [name, uniqe_name(name.gsub(/\s{2,}/, ' '))]
    update_attribute(:name, new_name)
    rename_in_cards(old_name, new_name)
    rename_in_card_versions(old_name, new_name)
    rename_in_changes(old_name, new_name)
  end
  
  def uniqe_name(name, suffix=nil)
    generated_name = "#{name}#{suffix}"
    if name_availbe?(generated_name)
      generated_name
    else
      suffix ||= 0
      uniqe_name(name, suffix + 1)
    end
  end
  
  def name_availbe?(name)
    !project.card_types.any?{ |type| type.name.downcase == name.downcase }
  end
  
  def rename_in_cards(old_name, new_name)
    update_table_column(project.card_table_name, 'card_type_name', old_name, new_name)
  end
  
  def rename_in_card_versions(old_name, new_name)
    update_table_column(project.card_version_table_name, 'card_type_name', old_name, new_name)
  end
  
  def rename_in_changes(old_name, new_name)
    ['new_value', 'old_value'].each do |column_name|
      sql = SqlHelper.sanitize_sql("UPDATE #{tbl('changes')} SET #{column_name} = ? WHERE field = ? AND #{column_name}= ? 
          AND event_id in (SELECT id FROM #{tbl('events')} WHERE project_id = ? )", new_name, 'Type', old_name, project_id)
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end

class CompactSpacesInNameOfCardTypes < ActiveRecord::Migration
  def self.up
    M169CardType.find(:all).each do |card_type|
      card_type.compact_spaces_in_name
    end
  end

  def self.down
  end
end
