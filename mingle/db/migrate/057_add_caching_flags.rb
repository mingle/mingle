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

class AddCachingFlags < ActiveRecord::Migration
  
  def self.all_tables
    tables = [:pages, :page_versions, :cards, :card_versions]
    project_identifiers = ActiveRecord::Base.connection.select_all("SELECT identifier FROM #{safe_table_name('projects')}").map{|record| record['identifier']}
    project_identifiers.each do |identifier|
      tables << "#{identifier}_cards"
      tables << "#{identifier}_card_versions"
    end
    tables
  end
  
  def self.up
    tables = all_tables
    
    tables.each do |table|
      add_column table, :has_macros, :boolean
    end
    
    tables.each do |table|
      ActiveRecord::Base.connection.execute(SqlHelper.sanitize_sql("UPDATE #{safe_table_name(table)} SET has_macros = ?", false))
    end
    
    tables.each do |table|
      change_column table, :has_macros, :boolean, :null => false, :default => false
    end
    
    Page.reset_column_information
    Page::Version.reset_column_information
  end

  def self.down
    all_tables.each do |table|
      remove_column table, :has_macros
    end
    
    Page.reset_column_information
    Page::Version.reset_column_information    
  end
end
