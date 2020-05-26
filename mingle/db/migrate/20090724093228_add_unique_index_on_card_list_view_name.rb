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

class AddUniqueIndexOnCardListViewName < ActiveRecord::Migration
  class M20090724Project < ActiveRecord::Base
    set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  end
  
  def self.up
    connection = ActiveRecord::Base.connection
    M20090724Project.all.each do |project|
      card_list_view_names = connection.select_values(%{
        SELECT name FROM #{safe_table_name('card_list_views')} WHERE #{connection.quote_column_name('project_id')} = #{project.id}
      })
      duplicated_card_list_view_names = card_list_view_names.inject(Hash.new(0)){ |hash, name| hash[name] += 1; hash }.reject{|name, value| value == 1}.keys
      duplicated_card_list_view_names.each do |view_name|
        name_duplicated_records = connection.select_all(%{
          SELECT * FROM #{safe_table_name('card_list_views')}
          WHERE #{connection.quote_column_name('name')} = '#{view_name}' AND #{connection.quote_column_name('project_id')} = #{project_id}
        })
        name_duplicated_records.each_with_index do |view_record, index|
          sql = %{
            UPDATE #{safe_table_name('card_list_views')}
            SET #{connection.quote_column_name('name')} = '#{view_record['name'] + index.to_s}'
            WHERE id = #{view_record['id']} AND #{connection.quote_column_name('project_id')} = #{project.id}
          }
          connection.execute(sql)
        end
      end
    end
    add_index :card_list_views, [:name, :project_id], :unique => true, :name => "#{ActiveRecord::Base.table_name_prefix}index_card_list_view_name"
  end

  def self.down
    remove_index :card_list_views, :name => "#{ActiveRecord::Base.table_name_prefix}index_card_list_view_name"
  end
end
