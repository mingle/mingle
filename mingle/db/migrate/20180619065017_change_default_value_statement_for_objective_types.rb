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

class ChangeDefaultValueStatementForObjectiveTypes < ActiveRecord::Migration

  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      execute sanitize_sql("UPDATE #{t('objective_types')} SET #{c('value_statement')} = ?", value_statement)
    end

    def value_statement
      '<h2>Context</h2>

<h3>Business Objective</h3>

<p><span>Whose life are we changing?</span></p>

<p><span>What problem are we solving?</span></p>

<p><span>Why do we care about solving this?</span></p>

<p><span>What is the successful outcome?</span></p>

<h3>Behaviours to Target</h3>

<p><span>(Example: Customer signup for newsletter, submitting support tickets, etc)</span></p>
'
    end

    def down
      # unnecessary
    end
  end
end
