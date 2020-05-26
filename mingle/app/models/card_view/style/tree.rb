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
  module Style
    class Tree < Base
      def filter_tabs(view)
        'cards/tree_filters_for_tree'
      end

      def popups_holder
        "TreeView.tree"
      end

      def displaying_cards(view)
        view.workspace.all_cards_query.find_cards
      end

      def displaying_card_count(view)
        view.as_card_query.card_count
      end

      def find_card_numbers(view)
        view.workspace.expanded_cards_tree.as_card_query.find_card_numbers
      end

      def clear_not_applicable_params!(params)
        [:group_by, :color_by, :lanes].each{|param| params.delete_ignore_case(param)}
      end

      def card_query_order_by(view)
        [CardQuery::Column.new('name')]
      end

      def color_by_property_definition(view)
        CardTypeDefinition::INSTANCE
      end

      def current_page(view)
        nil
      end

      def to_s
        'tree'
      end
    end
  end
end
