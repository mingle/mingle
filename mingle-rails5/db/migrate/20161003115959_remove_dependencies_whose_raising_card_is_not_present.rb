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

class RemoveDependenciesWhoseRaisingCardIsNotPresent < ActiveRecord::Migration[5.0]
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      [Dependency, Dependency::Version].each do |dependency_model|
        iterate_over_and_fix(dependency_model)
      end
    end

    def down
    end

    def iterate_over_and_fix(dependency_model)
      dependency_table = dependency_model.quoted_table_name
      return unless table_exists?(dependency_table)

      dependency_resolving_cards_table = DependencyResolvingCard.quoted_table_name
      (execute sanitize_sql("SELECT #{c('id')}, #{c('raising_project_id')}, #{c('raising_card_number')} FROM #{dependency_table}")).each do |entry|
        cards_tables = execute(sanitize_sql("SELECT #{c('cards_table')} FROM #{t('deliverables')} WHERE #{c('id')} = ? AND #{c('type')} = '#{Project.name}'", entry['raising_project_id']))
        next if cards_tables.size == 0

        card_table = cards_tables.first['cards_table']
        next unless table_exists?(card_table)

        result = execute(sanitize_sql("SELECT #{c('number')} FROM #{card_table} WHERE #{c('number')} = ?", entry['raising_card_number']))
        if result.empty?
          execute(sanitize_sql("DELETE FROM #{dependency_table} WHERE #{c('id')} = ?", entry['id']))
          execute(sanitize_sql("DELETE FROM #{dependency_resolving_cards_table} where #{c('dependency_id')} = ? and #{c('dependency_type')} = ?", entry['id'], dependency_model.name)) if table_exists?(dependency_resolving_cards_table)
        end
      end
    end

  end
end
