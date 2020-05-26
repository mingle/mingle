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

module Bulk
  class BulkUpdateTool
    include SqlHelper

    def initialize(project)
      @project = project
    end

    def card_ids(cards_that_changed_condition)
      sql = "SELECT id FROM #{Card.quoted_table_name} WHERE #{cards_that_changed_condition} ORDER BY id DESC"
      @project.connection.select_values(sql)
    end

    def update_search_index(cards_that_changed_condition)
      FullTextSearch.index_card_selection(@project, card_ids(cards_that_changed_condition))
    end

    def update_card_table(options)
      set = options[:set]
      conditions = options[:where]

      TemporaryIdStorage.with_session do |session_id|
        connection.insert_into(:table => TemporaryIdStorage.table_name,
                               :insert_columns => ['id_1', 'session_id'],
                               :select_columns => ["#{Card.quoted_table_name}.id", "'#{session_id}'"],
                               :from => Card.quoted_table_name,
                               :where => conditions,
                               :generate_id => false)

        connection.bulk_update(:table => Card.table_name, :set => set, :where => "#{Card.quoted_table_name}.id IN (SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{session_id}')")
      end
    end

    def card_types_from_selected_cards(card_id_criteria)
      CardType.find_by_sql(%{ SELECT ct.* FROM #{CardType.table_name} ct
                              WHERE LOWER(ct.name) IN (SELECT LOWER(card_type_name) FROM #{Card.quoted_table_name} WHERE id #{card_id_criteria.to_sql}) AND
                              ct.project_id = #{@project.id}
                            })
    end

    def compute_aggregates(tree_configuration, card_id_criteria)
      tree_configuration.compute_aggregates_for_unique_ancestors(card_id_criteria)
    end

    def card_versioning
      Bulk::BulkVersioning.new(@project)
    end
  end
end
