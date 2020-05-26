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

class StopPersonalFavoritesThatHadAccidentallyBecomeTabsFromBeingTabs < ActiveRecord::Migration
  def self.up
    # change all personal favorites to tab_view = false
    execute(sanitize_sql("update #{safe_table_name('favorites')} set tab_view = ? where user_id is not null and tab_view = ? and favorited_type = 'Page'", false, true))
    
    # remove duplicate rows potentially created by previous sql
    personal_favorites = select_all("select * from #{safe_table_name('favorites')} where user_id is not null and favorited_type = 'Page';")
    
    to_get_rid_of = []
    done = []
    
    personal_favorites.each do |row|
      done << row['id']
      if personal_favorites.any? { |other| row['id'] != other['id'] && row['favorited_id'] == other['favorited_id'] && row['user_id'] == other['user_id'] && !done.include?(other['id'])}
        to_get_rid_of << row['id']
      end
    end
    
    if to_get_rid_of.any?
      execute("delete from #{safe_table_name('favorites')} where id in (#{to_get_rid_of.join(',')})")
    end
  end

  def self.down
  end
end
