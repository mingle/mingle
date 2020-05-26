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

class AddMoreUserPreferences < ActiveRecord::Migration
  
  def self.up
    add_column :user_display_preferences, :color_legend_visible, :boolean
    add_column :user_display_preferences, :filters_visible, :boolean
    add_column :user_display_preferences, :history_have_been_visible, :boolean
    add_column :user_display_preferences, :history_changed_to_visible, :boolean
    add_column :user_display_preferences, :excel_import_export_visible, :boolean
    add_column :user_display_preferences, :firebug_warning_visible, :boolean
    remove_column :users, :ignore_firebugs_warning
    User.reset_column_information
    
    udpate_sql = %{
      UPDATE #{safe_table_name("user_display_preferences")} SET 
        color_legend_visible = ?, 
        filters_visible = ?,
        history_have_been_visible = ?,
        history_changed_to_visible = ?,
        excel_import_export_visible = ?,
        firebug_warning_visible = ?
    }
    update_sql = SqlHelper.sanitize_sql(udpate_sql, true, true, true, true, false, true)
    execute(update_sql)
    
    change_column :user_display_preferences, :color_legend_visible, :boolean, :null => false
    change_column :user_display_preferences, :filters_visible, :boolean, :null => false
    change_column :user_display_preferences, :history_have_been_visible, :boolean, :null => false
    change_column :user_display_preferences, :history_changed_to_visible, :boolean, :null => false
    change_column :user_display_preferences, :excel_import_export_visible, :boolean, :null => false
    change_column :user_display_preferences, :firebug_warning_visible, :boolean, :null => false
  end

  def self.down
    remove_column :user_display_preferences, :color_legend_visible
    remove_column :user_display_preferences, :filters_visible
    remove_column :user_display_preferences, :history_have_been_visible
    remove_column :user_display_preferences, :history_changed_to_visible
    remove_column :user_display_preferences, :excel_import_export_visible
    remove_column :user_display_preferences, :firebug_warning_visible
    add_column :users, :ignore_firebugs_warning, :boolean, :null => true
    User.reset_column_information
  end
  
end
