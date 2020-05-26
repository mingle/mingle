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

module CardView

  module GridViewCards
    module Indexed
      attr_accessor :index_in_card_list_view
    end

    module HavingChildren
      attr_accessor :ancestors

      def ancestor_numbers
        (ancestors || []).join(",")
      end
    end

    def used_group_by_row_property_values
      cards.collect do |card|
        self.row_property_definition.db_identifier(card)
      end.uniq.collect do |db_identifier|
        self.row_property_definition.property_value_from_db(db_identifier)
      end
    end

    def cards
      @cards ||= mark_card_index(make_not_set_cards_be_last(extend_behaviors(@view.cards)))
    end

    private
    def extend_behaviors(cards)
      cards.each do |card|
        card.extend Indexed
        card.extend HavingChildren
      end
    end

    def make_not_set_cards_be_last(cards)
      return cards unless grid_sort_by
      grid_sort_by_prop = @project.find_property_definition_or_nil(grid_sort_by)
      not_set_cards = cards.select do |card|
        grid_sort_by_prop.db_identifier(card).blank?
      end
      not_set_cards.blank? ? cards : ((cards - not_set_cards) + not_set_cards)
    end

    def mark_card_index(cards)
      cards.each_with_index do |card, index|
        card.index_in_card_list_view = index
      end
      cards
    end

  end

end
