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

class M113Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
end

class FixCardVersionsWithoutCardTypeName < ActiveRecord::Migration
  def self.up
    M113Project.find(:all).each do |project|
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_cards")
      card_table_name = safe_table_name "#{project.identifier}_cards"
      card_versions_table_name = safe_table_name "#{project.identifier}_card_versions"
      patched_card_types = project.class.connection.select_all %{
        select 
          v1.#{quote_column_name('number')} as card_number
          , max(v1.version) as highest_version_with_type
          , v1.card_type_name as corrected_card_type
        from 
          #{card_table_name} v 
          join #{card_versions_table_name} v1 on (v1.#{quote_column_name('number')} = v.#{quote_column_name('number')} and v1.version = v.version + 1)
        where 
          v.card_type_name = '' and v1.card_type_name != ''
        group by
          v1.#{quote_column_name('number')}, v1.card_type_name
        order by 
          v1.#{quote_column_name('number')}
      }
      patched_card_types.each do |row|
        fix_version_row_sql = SqlHelper.sanitize_sql(%{
          update
            #{card_versions_table_name}
          set
            card_type_name = ?
          where
            #{quote_column_name('number')} = ? and card_type_name = ''
        }, row['corrected_card_type'], row['card_number'])
        ActiveRecord::Base.connection.execute(fix_version_row_sql)
      end  
    end  
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration, "data patch. should not be reversed to recreate bad data!"
  end
end
