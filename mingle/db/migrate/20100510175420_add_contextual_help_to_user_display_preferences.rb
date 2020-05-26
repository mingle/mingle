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

class AddContextualHelpToUserDisplayPreferences < ActiveRecord::Migration
  def self.up
    add_column :user_display_preferences, :contextual_help, :text, :null => false, :default => {}
    M20100510175420UserDisplayPreference.all.each do |user_display_preference|
      user_display_preference.update_attribute :contextual_help, {:murmurs_index => user_display_preference.ch_murmurs_index, :history_index => user_display_preference.ch_history_index}
    end
    remove_column :user_display_preferences, :ch_murmurs_index
    remove_column :user_display_preferences, :ch_history_index
  end

  def self.down
    remove_column :user_display_preferences, :contextual_help
    add_column :user_display_preferences, :ch_history_index, :boolean, :null => false, :default => true
    add_column :user_display_preferences, :ch_murmurs_index, :boolean, :null => false, :default => true
  end
end

class M20100510175420UserDisplayPreference < ActiveRecord::Base
  serialize :contextual_help
  set_table_name "#{ActiveRecord::Base.table_name_prefix}user_display_preferences"
end
