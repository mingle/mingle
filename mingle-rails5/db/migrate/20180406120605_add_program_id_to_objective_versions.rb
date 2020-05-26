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

class AddProgramIdToObjectiveVersions < ActiveRecord::Migration[5.0]
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      add_column :objective_versions, :program_id, :integer
      plans = select_all sanitize_sql("SELECT * FROM #{t('plans')}")
      plans.each do |plan|
        execute sanitize_sql("UPDATE #{t('objective_versions')} SET #{c('program_id')} = '#{plan['program_id']}' WHERE #{c('plan_id')} = #{plan['id']}")
      end
    end

    def down
      remove_column :objective_versions, :program_id
    end
  end
end
