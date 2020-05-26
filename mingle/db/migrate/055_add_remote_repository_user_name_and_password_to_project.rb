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

class AddRemoteRepositoryUserNameAndPasswordToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :repository_user_name, :string
    add_column :projects, :repository_password, :string
    Project.reset_column_information
  end

  def self.down
    remove_column :projects, :repository_user_name
    remove_column :projects, :repository_password
    Project.reset_column_information
  end
end
