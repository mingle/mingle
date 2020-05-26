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

class DenormalizeCrossProjectStatusForPageAndCard < ActiveRecord::Migration
  
  class M128Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
    
    def card_table_name
      self.identifier + '_cards'
    end
    
    def card_version_table_name
      self.identifier + '_card_versions'
    end
  end
  
  def self.up
    M128Project.find(:all).each do |project|
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_cards")
      
      add_column project.card_table_name, :has_cross_project_macro, :boolean, :default => false rescue nil
      add_column project.card_version_table_name, :has_cross_project_macro, :boolean, :default => false rescue nil
    end
    
    add_column :pages, :has_cross_project_macro, :boolean, :default => false
    add_column :page_versions, :has_cross_project_macro, :boolean, :default => false
  end

  def self.down
    M128Project.find(:all).each do |project|
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_cards")
      
      remove_column project.card_table_name, :has_cross_project_macro
      remove_column project.card_version_table_name, :has_cross_project_macro
    end
    
    remove_column :pages, :has_cross_project_macro
    remove_column :page_versions, :has_cross_project_macro
  end
end
