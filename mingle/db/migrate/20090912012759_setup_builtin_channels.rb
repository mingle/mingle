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

class SetupBuiltinChannels < ActiveRecord::Migration
  def self.up
    update_type_sql = <<-SQL
      UPDATE #{ActiveRecord::Base.table_name_prefix}murmur_channels
      SET type = ?
      WHERE type IS NULL
    SQL
    ActiveRecord::Base.connection.execute(sanitize_sql(update_type_sql, 'BuiltInChannel'))
    
    update_enabled_sql = <<-SQL
      UPDATE #{ActiveRecord::Base.table_name_prefix}murmur_channels
      SET enabled = ?
      WHERE enabled IS NULL
    SQL
    ActiveRecord::Base.connection.execute(sanitize_sql(update_enabled_sql, true))
  end

  def self.down
  end
end
