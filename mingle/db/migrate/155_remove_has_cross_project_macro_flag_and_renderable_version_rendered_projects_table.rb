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

class RemoveHasCrossProjectMacroFlagAndRenderableVersionRenderedProjectsTable < ActiveRecord::Migration    
  class M155Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
    
    def card_table_name
      self.identifier + '_cards'
    end
    
    def card_version_table_name
      self.identifier + '_card_versions'
    end
  end
  
  def self.up
    M155Project.find(:all).each do |project|
      remove_cross_project_flag_if_exits(project.card_table_name, project.card_version_table_name)
    end
    remove_cross_project_flag_if_exits("pages", "page_versions")
    
    drop_table 'renderable_version_rendered_projects'
  end
  
  def self.remove_cross_project_flag_if_exits(*tables)
    tables.each do |table|
      next unless columns(table).collect(&:name).include?('has_cross_project_macro')
      remove_column table, 'has_cross_project_macro'        
    end
  end

  def self.down
    create_table :renderable_version_rendered_projects, :force => true do |t|
      t.column "renderable_version_id",   :integer, :null => false
      t.column "renderable_version_type",   :string, :null => false
      t.column "rendered_project_id", :integer, :null => false
    end
    
    M155Project.find(:all).each do |project|
      add_column project.card_table_name, 'has_cross_project_macro', :boolean
      add_column project.card_version_table_name, 'has_cross_project_macro', :boolean
    end
    
    add_column "pages", 'has_cross_project_macro', :boolean
    add_column "page_versions", 'has_cross_project_macro', :boolean
  end
  
end
