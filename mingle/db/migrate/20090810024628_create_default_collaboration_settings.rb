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

class M20090810024628CollaborationSettings < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}collaboration_settings"
end

class M20090810024628Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_one :collaboration_settings, :class_name => 'M20090810024628CollaborationSettings', :foreign_key => 'project_id'
end

class CreateDefaultCollaborationSettings < ActiveRecord::Migration  
  def self.up
    M20090810024628Project.find(:all, :conditions => ['template = ? OR template IS NULL', false]).each do |project|
      M20090810024628CollaborationSettings.create(:project_id => project.id) unless project.collaboration_settings
    end
  end

  def self.down
  end
end
