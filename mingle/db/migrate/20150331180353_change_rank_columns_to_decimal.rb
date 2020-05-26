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

class ChangeRankColumnsToDecimal < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      each_project do |id, identifier, ct, cvt|
        next unless table_exists?(ct)

        column = connection.columns(t(ct)).find {|c| c.name.downcase == "project_card_rank"}
        next unless (column.nil? || column.type == :integer || column.sql_type == "NUMBER(38,0)" || column.sql_type.downcase =~ /int/)

        change_column ct, "project_card_rank", :decimal
      end

      if table_exists?("cards")
        change_column "cards", "project_card_rank", :decimal
      end

    end

    def down
      raise "Not going to revert back to integer because it requires data migration."
    end

  end
end
