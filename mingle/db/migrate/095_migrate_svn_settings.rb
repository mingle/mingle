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

class MigrateSvnSettings < ActiveRecord::Migration
  class M95Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  end
  
  class M95SubversionConfiguration < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}subversion_configurations"
  end
  
  def self.up
    M95Project.find(:all).each do |project|
      next if project.repository_path.blank?
      M95SubversionConfiguration.create!(
        :project_id => project.id, 
        :username => project.repository_user_name, 
        :password => project.repository_password, 
        :repository_path => project.repository_path)
      project.update_attribute(:repository_type, 'subversion')
    end
  end

  def self.down
  end
end
