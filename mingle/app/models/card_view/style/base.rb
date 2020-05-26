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
    class Base
      def filter_tabs(view)
        view.workspace.tree_workspace? ? 'cards/tree_filters' : 'shared/filters'
      end

      def results_partial
        "cards/card_#{self.to_s}_results"
      end

      def action_panel_partial
        "cards/card_#{self.to_s}_action_panel"
      end

      def describe_current_page(view)
        ''
      end

      def card_query_order_by(view)
        if view.has_valid_sort_order?
          [CardQuery::Column.new(view.sort, view.order)]
        end
      end

      def current_page(view)
        raise 'Not Implemented'
      end
    end
  end
end
