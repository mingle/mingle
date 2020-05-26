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

class RedistributeCardRanks < ActiveRecord::Migration
  class << self
    alias_method :c, :quote_column_name
    alias_method :t, :safe_table_name

    def up
      each_project do |id, identifier, cards_table, card_versions_table|
        next unless table_exists?(cards_table)

        type = ActiveRecord::Base.connection.database_vendor
        sql = if type == :oracle
          %Q{
         MERGE INTO #{t(cards_table)} t1
              USING (SELECT id, ((row_number() OVER (ORDER BY #{c(rank_column)}) * 1024.0) + -4294967296.0) AS new_rank FROM #{t(cards_table)}) t2
                 ON (t1.id = t2.id)
  WHEN MATCHED THEN
         UPDATE SET t1.#{c(rank_column)} = t2.new_rank
          }
        else
          %Q{
            UPDATE #{t(cards_table)}
               SET #{c(rank_column)} = t2.new_rank
              FROM (select id, ((row_number() over (order by #{c(rank_column)}) * 1024.0) + -4294967296.0) as new_rank from #{t(cards_table)}) t2
             WHERE #{t(cards_table)}.id = t2.id
          }
        end.strip

        execute(sql)
      end
    end

    def down
      # there's no going back now
    end

    def rank_column
      Card::CardRanking::RANK_COLUMN
    end

  end
end
