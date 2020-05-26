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

class AddCachingStampToCards < ActiveRecord::Migration
  
  class M153Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"

    def card_table_name
      "#{identifier}_cards"
    end
  end
  
  def self.up
    M153Project.find(:all).each do |project|
      add_column project.card_table_name, :caching_stamp, :integer
      udpate_sql = %{
        UPDATE #{safe_table_name(project.card_table_name)} SET 
          caching_stamp = ? 
      }
      update_sql = SqlHelper.sanitize_sql(udpate_sql, 0)
      execute(update_sql)
      change_column project.card_table_name, :caching_stamp, :integer, :null => false, :default => 0
    end
  end

  def self.down
    M153Project.find(:all).each do |project|
      remove_column project.card_table_name, :caching_stamp
    end
  end
end
