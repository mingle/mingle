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
  class CreateMissingLoginAccessForUsers < Base

    def self.description
      "This data fix is for fixing User record does not have LoginAccess record associated with it. Normally this situation happens project import breaks for some reason during the process of importing user. The inconsistent user record can cause 500 error on user list pages."
    end

    def self.required?
      user_ids_with_missing_login_access.any?
    end

    def self.apply(project_ids=[])
      user_ids_with_missing_login_access.each do |user_id|
        ActiveRecord::Base.connection.execute(sanitize_sql(<<SQL, user_id))
INSERT INTO #{safe_table_name('login_access')} (id, user_id)
VALUES ((#{ActiveRecord::Base.connection.next_id_sql('login_access')}), ?)
SQL
      end
    end

    private
    def self.user_ids_with_missing_login_access
      ActiveRecord::Base.connection.select_values(<<-SQL)
SELECT #{quote_column_name('id')}
FROM #{safe_table_name('users')}
WHERE #{quote_column_name('id')} NOT IN (
  SELECT #{quote_column_name('user_id')}
  FROM #{safe_table_name('login_access')})
SQL
    end
  end
end
