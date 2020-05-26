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

class EnsureRankIsUnique < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      each_project do |id, identifier, ct, cvt|
        next unless table_exists?(ct)
        add_index ct, "project_card_rank", :unique => true
      end

      if table_exists?("cards")
        add_index "cards", "project_card_rank", :unique => true
      end
    end

    def down
      each_project do |id, identifier, ct, cvt|
        remove_index ct, "project_card_rank"
      end

      if table_exists?("cards")
        remove_index "cards", "project_card_rank"
      end
    end

  end
end
