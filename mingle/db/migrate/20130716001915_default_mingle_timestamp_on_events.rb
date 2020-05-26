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

class DefaultMingleTimestampOnEvents < ActiveRecord::Migration
  def self.up
    case connection.database_vendor
    when :postgresql
      execute "ALTER TABLE #{safe_table_name('events')} ALTER COLUMN #{quote_column_name('mingle_timestamp')} SET DEFAULT clock_timestamp() at time zone 'utc'"
    when :oracle
      execute "ALTER TABLE #{safe_table_name('events')} MODIFY #{quote_column_name('mingle_timestamp')} DEFAULT sys_extract_utc(CURRENT_TIMESTAMP)"
    end
  end

  def self.down
    case connection.database_vendor
    when :postgresql
      execute "ALTER TABLE #{safe_table_name('events')} ALTER COLUMN #{quote_column_name('mingle_timestamp')} DROP DEFAULT"
    when :oracle
      execute "ALTER TABLE #{safe_table_name('events')} MODIFY #{quote_column_name('mingle_timestamp')} DEFAULT NULL"
    end
  end
end
