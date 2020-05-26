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

class FixFavoritesAssociatedWithNonExistentProjects < ActiveRecord::Migration
  def self.up
      execute(%Q{
      DELETE FROM #{Favorite.quoted_table_name}
      WHERE #{quote_column_name('id')}
      IN (SELECT fav.id
          FROM #{Favorite.quoted_table_name} fav
          FULL OUTER JOIN #{Deliverable.quoted_table_name} d
          ON fav.project_id = d.id
          WHERE d.id IS NULL)
    })
  end

  def self.down
  end
end
