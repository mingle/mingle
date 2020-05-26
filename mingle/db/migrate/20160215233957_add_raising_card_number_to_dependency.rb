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

class AddRaisingCardNumberToDependency < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      add_column(:dependencies, :raising_card_number, :integer) unless column_exists?(:dependencies, :raising_card_number)
      add_column(:dependency_versions, :raising_card_number, :integer) unless column_exists?(:dependency_versions, :raising_card_number)
      Dependency.reset_column_information
      ["dependencies", "dependency_versions"].each do |deptable|
        iterate_over(deptable) do |dt, dep_id, cards_table, card_id|
          execute sanitize_sql(%{
            UPDATE #{dt}
               SET #{c("raising_card_number")} = (SELECT #{c("number")} FROM #{cards_table} WHERE #{c("id")} = ?)
             WHERE #{c("id")} = ?
            }, card_id, dep_id)
        end
      end
    end

    def down
      remove_column :dependencies, :raising_card_number if column_exists?(:dependencies, :raising_card_number)
      remove_column :dependency_versions, :raising_card_number if column_exists?(:dependency_versions, :raising_card_number)
      Dependency.reset_column_information
    end

    def iterate_over(table, &block)
      (execute sanitize_sql("SELECT #{c("id")}, #{c("raising_project_id")}, #{c("raising_card_id")} FROM #{t(table)}")).each do |entry|
        cards_tables = execute(sanitize_sql("SELECT #{c("cards_table")} FROM #{t("deliverables")} WHERE #{c("id")} = ? AND #{c("type")} = 'Project'", entry["raising_project_id"]))
        next if cards_tables.size == 0
        block.call(t(table), entry["id"], cards_tables.first["cards_table"], entry["raising_card_id"]) if block_given?
      end
    end
  end
end
