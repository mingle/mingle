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

class AddLoginAccessTable < ActiveRecord::Migration
  
  def self.up
    create_table  :login_access do |t|
      t.integer   :user_id, :null => false
      t.string    :login_token
      t.datetime  :last_login
      t.string    :lost_password_key, :limit => safe_limit(4096)
      t.datetime  :lost_password_reported_at
    end
    
    execute <<-SQL
      INSERT INTO #{safe_table_name('login_access')} (id, user_id, login_token, lost_password_key, lost_password_reported_at)
      SELECT (#{ActiveRecord::Base.connection.next_id_sql(safe_table_name("login_access"))}), id, login_token, lost_password_key, lost_password_reported_at FROM #{safe_table_name('users')}
    SQL
    
    remove_column :users, :login_token
    remove_column :users, :lost_password_key
    remove_column :users, :lost_password_reported_at
  end

  def self.down
    drop_table :login_access
  end
end
