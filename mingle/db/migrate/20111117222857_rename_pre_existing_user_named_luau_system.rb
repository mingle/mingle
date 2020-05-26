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

class RenamePreExistingUserNamedLuauSystem < ActiveRecord::Migration
  def self.user_with_login_exist?(login)
    ActiveRecord::Base.connection.select_value(sanitize_sql(%{
      SELECT count(id) 
      FROM #{safe_table_name('users')}
      WHERE login=? AND system=?
    }, login, false)).to_i > 0
  end
  
  def self.first_not_occupied_login(base_login, suffix)
    login = "#{base_login}#{suffix}"
    user_with_login_exist?(login) ? first_not_occupied_login(base_login, suffix + 1) : login
  end
  
  def self.up
    return unless user_with_login_exist?('luau_system')
    new_login = first_not_occupied_login('luau_system', 1)
    execute(sanitize_sql("UPDATE #{safe_table_name('users')} SET login=? WHERE login=? AND system=?", new_login, 'luau_system', false))
  end

  def self.down
  end
end
