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

class StaleProjectDataFixForFavorites < ActiveRecord::Migration
  def self.up
    execute(%Q{
      DELETE FROM #{CardListView.quoted_table_name}
      WHERE #{quote_column_name('project_id')}
      IN (SELECT DISTINCT clv.project_id
          FROM #{CardListView.quoted_table_name} clv
          LEFT JOIN #{Deliverable.quoted_table_name} d
          ON clv.project_id = d.id
          WHERE d.id IS NULL)
    })
  end

  def self.down
  end
end
