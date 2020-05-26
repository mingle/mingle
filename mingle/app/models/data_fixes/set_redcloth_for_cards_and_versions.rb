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

module DataFixes
  class SetRedclothForCardsAndVersions < Base

    def self.description
      "This data fix is for fixing redcloth column was not migrated and left as nil problem (see bug #15281). Customer already started use the project imported, so we need this to set redcloth column to true and force card/card_version description getting converted to WYSIWYG format. The \"required\" means there is at least one redcloth value is NULL in database."
    end

    def self.required?
      problem_tables.size > 0
    end

    def self.apply(project_ids=[])
      problem_tables.each do |t|
        ActiveRecord::Base.connection.execute(sanitize_sql(<<SQL, true))
UPDATE #{quote_table_name(t)} SET redcloth = ? WHERE redcloth IS NULL
SQL
      end
    end

    def self.problem_tables
      Project.all.map do |proj|
        [proj.cards_table, proj.card_versions_table]
      end.flatten.select do |t|
        ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{t} WHERE redcloth IS NULL").to_i > 0
      end
    end
  end
end
