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

class RestructDailyHistoryMessagesTable < ActiveRecord::Migration
  def self.up
    execute("DELETE FROM #{safe_table_name('daily_history_messages')}")
    add_column :daily_history_messages, 'content_provider_type',  :string,    :null => false
    add_column :daily_history_messages, 'content_provider_id',    :integer,   :null => false
    add_column :daily_history_messages, 'chart_raw_content',      :text,      :null => false
    add_column :daily_history_messages, 'process_after',          :datetime,  :null => false

    remove_column :daily_history_messages, 'mql'
    remove_column :daily_history_messages, 'end_time_of_date_in_utc'
  end

  def self.down
    remove_column :daily_history_messages, 'content_provider_type'
    remove_column :daily_history_messages, 'content_provider_id'
    remove_column :daily_history_messages, 'chart_raw_content'
    remove_column :daily_history_messages, 'process_after'

    add_column :daily_history_messages, 'mql',                      :text, :null => false
    add_column :daily_history_messages, 'end_time_of_date_in_utc',  :datetime, :null => false
  end
end
