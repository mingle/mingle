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

class AddCardNumberToDependencyResolvingCards < ActiveRecord::Migration
  def self.up
    add_column :dependency_resolving_cards, :card_number, :integer unless column_exists?(:dependency_resolving_cards, :card_number)

    update_dependency_resolving_cards_table_for(Dependency)
    update_dependency_resolving_cards_table_for(Dependency::Version)
  end

  def self.down
    remove_column :dependency_resolving_cards, :card_number
  end

  def self.update_dependency_resolving_cards_table_for(dependency_type)
    dep_resolving_cards = execute sanitize_sql("SELECT * FROM #{safe_table_name('dependency_resolving_cards')} WHERE #{quote_column_name('dependency_type')}='#{dependency_type.name}'")
    dep_resolving_cards.each do |entry|
      result = execute(sanitize_sql(%{
        SELECT #{quote_column_name('cards_table')} FROM #{safe_table_name('deliverables')} "projects"
          WHERE "projects".#{quote_column_name('id')} =
            (SELECT "deps".#{quote_column_name('resolving_project_id')} FROM #{safe_table_name(dependency_type.table_name)} "deps"
              WHERE "deps".#{quote_column_name('id')}=#{entry['dependency_id']})
        }))
      next if result.size == 0
      cards_table_name = result.first['cards_table']

      execute sanitize_sql(%{
        UPDATE #{safe_table_name('dependency_resolving_cards')} SET #{quote_column_name('card_number')} =
          (SELECT "project_cards".#{quote_column_name('number')} FROM #{cards_table_name} "project_cards"
            WHERE #{quote_column_name('card_id')} = "project_cards".#{quote_column_name('id')})
              WHERE #{quote_column_name('id')} = #{entry["id"]}
       })
    end
  end
end
