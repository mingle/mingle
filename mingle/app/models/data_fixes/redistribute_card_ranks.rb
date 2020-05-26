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
  class RedistributeCardRanks < Base

    INTERVAL = 65536

    class << self

      # this datafix could take a long time depending on cards table sizes and
      # whether or not a lock can be acquired in a timely manner; making this
      # asynchronous will prevent request timeouts
      def queued?
        true
      end

      def description
        %Q{
          Redistribute card ranks to fix bottom-clustering of rank values resulting from an older ranking algorithm. The algorithm used in this data fix will work as long as a project has less than <strong>56 trillion cards.</strong> In other words, don't worry about it.
        }
      end

      def apply(project_ids=[])
        each_project do |id, identifier, cards_table, card_versions_table|
          next unless ActiveRecord::Base.connection.table_exists?(t(cards_table))

          idx_name = ActiveRecord::Base.connection.index_name(cards_table, "project_card_rank")

          begin
            # temporarily remove unique index
            ActiveRecord::Base.connection.remove_index(cards_table, "project_card_rank") if ActiveRecord::Base.connection.index_exists?(cards_table, idx_name, nil)

            ActiveRecord::Base.connection.redistribute_project_card_rank(t(cards_table), Card::CardRanking::RANK_MIN, INTERVAL)
          ensure
            # recreate unique index
            ActiveRecord::Base.connection.add_index(cards_table, "project_card_rank", :unique => true, :name => idx_name) unless ActiveRecord::Base.connection.index_exists?(cards_table, idx_name, nil)
          end

        end
      end

      def rank_column
        Card::CardRanking::RANK_COLUMN
      end

    end
  end
end
