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

module DataFixes
  class CleanOrphanCardDefaults < Base

    def self.description
      "This data fix is for removing orphan card defaults whose card_type_id pointing to a non-exists card type"
    end

    def self.required?
      results = ActiveRecord::Base.connection.select_values(<<-SQL)
SELECT 1
FROM #{safe_table_name('card_defaults')}
WHERE #{quote_column_name('card_type_id')} NOT IN (
  SELECT #{quote_column_name('id')}
  FROM #{safe_table_name('card_types')}
)
SQL
      results.any?
    end

    def self.apply(project_ids=[])
      ActiveRecord::Base.connection.execute(<<SQL)
DELETE FROM #{safe_table_name('card_defaults')}
WHERE #{quote_column_name('card_type_id')} NOT IN (
  SELECT #{quote_column_name('id')}
  FROM #{safe_table_name('card_types')}
)
SQL
    end

  end
end
