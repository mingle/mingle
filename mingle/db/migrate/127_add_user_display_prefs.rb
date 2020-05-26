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

class AddUserDisplayPrefs < ActiveRecord::Migration
  def self.up
    create_table :user_display_preferences, :force => true do |t|
      t.column "user_id",   :integer, :null => false
      t.column "sidebar_visible",   :boolean, :null => false
      t.column "favorites_visible",   :boolean, :null => false
      t.column "recent_pages_visible",   :boolean, :null => false
    end
  end

  def self.down
    drop_table :user_display_preferences
  end
end
