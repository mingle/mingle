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

class MoveCardCachingStampToCardTable < ActiveRecord::Migration
  include MigrationHelper
  
  class M20091012061534Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
    
    def card_table_name
      CardSchema.generate_cards_table_name(self.identifier)
    end
  end
  
  def self.up
    M20091012061534Project.all.each do |project|
      add_column project.card_table_name, :caching_stamp, :integer
       udpate_sql = %{
         UPDATE #{safe_table_name(project.card_table_name)} SET 
           caching_stamp = ? 
       }
       update_sql = SqlHelper.sanitize_sql(udpate_sql, 0)
       execute(update_sql)
       
       change_column project.card_table_name, :caching_stamp, :integer, :null => false, :default => 0
    end
    drop_table :card_caching_stamps
  end

  def self.down
    create_table "card_caching_stamps", :force => true do |t|
      t.column "card_id",                :integer,  :null => false
      t.column "caching_stamp",          :integer,  :null => false, :default => 0
    end
    add_index(:card_caching_stamps, :card_id, :unique => true)
    
    M20091012061534Project.find(:all).each do |project|      
      insert_columns = ['card_id', 'caching_stamp']
      select_columns = ['id', 'caching_stamp']
      if prefetch_primary_key?
        insert_columns.unshift('id')
        select_columns.unshift(next_id_sql(safe_table_name('card_caching_stamps')))
      end
      
      execute %{ INSERT INTO #{safe_table_name("card_caching_stamps")} (#{insert_columns.join(",")})
               SELECT #{select_columns.join(",")} FROM #{safe_table_name(project.card_table_name)}             
      }
      
      remove_column project.card_table_name, :caching_stamp
    end
  end
end
