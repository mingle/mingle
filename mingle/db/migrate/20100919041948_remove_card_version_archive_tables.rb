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

class Project20100919041948 < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"

  def card_version_archive_table_name
    ActiveRecord::Base.connection.db_specific_table_name("#{identifier}_card_versions_archive")
  end
end

class RemoveCardVersionArchiveTables < ActiveRecord::Migration
  def self.up
    return if ActiveRecord::Base.table_name_prefix.starts_with?('mi_')

    Project20100919041948.all.each do |project|
      drop_table(project.card_version_archive_table_name) if table_exists?(project.card_version_archive_table_name)
    end

    execute %{
      DELETE FROM #{safe_table_name("changes")}
      WHERE event_id IN (
       SELECT id FROM #{safe_table_name("events")}
       WHERE origin_type = 'Card::Version::Archive'
      )
    }


    execute %{
      DELETE FROM #{safe_table_name("events")}
      WHERE origin_type = 'Card::Version::Archive'
    }

    case connection.database_vendor
    when :postgresql
      execute "DROP SEQUENCE IF EXISTS card_version_archive_id_seq"
    when :oracle
      execute "DROP SEQUENCE card_version_archive_id_seq" rescue nil
    end
  end

  def self.down
  end
end
