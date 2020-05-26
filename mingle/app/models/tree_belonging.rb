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

class TreeBelonging < ActiveRecord::Base
  belongs_to :tree_configuration
  belongs_to :card

  after_create :compute_aggregate_properties_for_card
  after_destroy :update_search_indexes

  private
  def update_search_indexes
    FullTextSearch::IndexingCardsProcessor.request_indexing([card])
  end

  def compute_aggregate_properties_for_card
    card.compute_aggregate_properties(:for_trees => [tree_configuration])
  end

  class << self
    def delete_all_from_type(card_type, tree)
      return unless card_type
      sql = SqlHelper.sanitize_sql("DELETE FROM #{self.table_name} WHERE tree_configuration_id = ? AND card_id in (SELECT id from #{Card.quoted_table_name} where card_type_name = ?)", tree.id, card_type.name)
      ActiveRecord::Base.connection.delete(sql)
    end
  end
end
