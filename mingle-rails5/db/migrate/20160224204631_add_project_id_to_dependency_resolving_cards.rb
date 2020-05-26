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

class AddProjectIdToDependencyResolvingCards < ActiveRecord::Migration[5.0]

  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      add_column :dependency_resolving_cards, :project_id, :integer
      execute(%Q{
        UPDATE #{t("dependency_resolving_cards")} drc
           SET project_id = (SELECT resolving_project_id FROM #{t("dependencies")} WHERE id = drc.dependency_id)
         WHERE dependency_type = 'Dependency'
      })

      execute(%Q{
        UPDATE #{t("dependency_resolving_cards")} drc
           SET project_id = (SELECT resolving_project_id FROM #{t("dependency_versions")} WHERE id = drc.dependency_id)
         WHERE dependency_type = 'Dependency::Version'
      })

      if connection.database_vendor == :oracle
        change_column :dependency_resolving_cards, :project_id, :integer, :null => false
      else
        execute %Q{
          ALTER TABLE #{t('dependency_resolving_cards')} ALTER COLUMN #{c('project_id')} SET NOT NULL
        }
      end
      DependencyResolvingCard.reset_column_information
    end

    def down
      remove_column :dependency_resolving_cards, :project_id
      DependencyResolvingCard.reset_column_information
    end

  end
end
