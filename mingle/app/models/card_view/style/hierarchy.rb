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
    class Hierarchy < Base
      def displaying_cards(view)
        tree = view.workspace.expanded_cards_tree
        tree.nodes_without_root
      end

      def displaying_card_count(view)
        view.as_card_query.card_count
      end

      def find_card_numbers(view)
        view.as_card_query.find_card_numbers
      end

      def clear_not_applicable_params!(params)
        [:group_by, :color_by, :lanes, :aggregate_property, :aggregate_type].each{|param| params.delete_ignore_case(param)}
      end

      def current_page(view)
        nil
      end

      def to_s
        'hierarchy'
      end

      def describe_current_page(view)
        "#{'cards'.enumerate(view.all_cards_size)} in view."
      end
    end
  end
end
