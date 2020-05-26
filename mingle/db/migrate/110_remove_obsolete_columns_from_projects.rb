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

class RemoveObsoleteColumnsFromProjects < ActiveRecord::Migration
  
  class M110Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  end
  
  class M110SubversionConfiguration < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}subversion_configurations"
  end
  
  def self.up
    remove_column :projects, :repository_path
    remove_column :projects, :repository_user_name
    remove_column :projects, :repository_password
    add_column :subversion_configurations, :revisions_invalid, :boolean
    add_column :subversion_configurations, :card_revision_links_invalid, :boolean
    add_column :subversion_configurations, :marked_for_deletion, :boolean, :default => false
    
    M110SubversionConfiguration.find(:all).each do |svn_config|
      project = M110Project.find(svn_config.project_id)
      svn_config.update_attributes(
        :revisions_invalid => project.revisions_invalid, 
        :card_revision_links_invalid => project.card_revision_links_invalid,
        :marked_for_deletion => false)
    end
    
    remove_column :projects, :revisions_invalid
    remove_column :projects, :card_revision_links_invalid
    
    Project.reset_column_information
    SubversionConfiguration.reset_column_information
  end

  def self.down
    add_column :projects, :repository_path, :string
    add_column :projects, :repository_user_name, :string
    add_column :projects, :repository_password, :string
    add_column :projects, :projects, :revisions_invalid, :boolean
    add_column :projects, :projects, :card_revision_links_invalid, :boolean
    
    M110SubversionConfiguration.find(:all).each do |svn_config|
      project = M110Project.find(svn_config.project_id)
      project.update_attributes(:revisions_invalid => svn_config.revisions_invalid, 
        :card_revision_links_invalid => svn_config.card_revision_links_invalid)
    end
    
    remove_column :subversion_configurations, :revisions_invalid
    remove_column :subversion_configurations, :card_revision_links_invalid
    remove_column :subversion_configurations, :marked_for_deletion
    
    Project.reset_column_information
    SubversionConfiguration.reset_column_information
  end
end
