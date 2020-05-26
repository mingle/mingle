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

class RenameColumnsInMurmurChannelsToEnabledAndConnected < ActiveRecord::Migration
  def self.up
    connection = ActiveRecord::Base.connection
    
    rename_column :murmur_channels, :disabled, :enabled
    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{ActiveRecord::Base.table_name_prefix}murmur_channels
         SET enabled = CASE WHEN enabled = #{connection.false_value} THEN #{connection.true_value} WHEN enabled = #{connection.true_value} THEN #{connection.false_value} END
    SQL
    
    rename_column :murmur_channels, :jabber_chat_room_enabled, :jabber_chat_room_connected
  end

  def self.down
    connection = ActiveRecord::Base.connection
    
    rename_column :murmur_channels, :enabled, :disabled
    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE #{ActiveRecord::Base.table_name_prefix}murmur_channels
         SET disabled = CASE WHEN disabled = #{connection.false_value} THEN #{connection.true_value} WHEN disabled = #{connection.true_value} THEN #{connection.false_value} END
    SQL
    
    rename_column :murmur_channels, :jabber_chat_room_connected, :jabber_chat_room_enabled
  end
end
