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
    class Grid < Base
      def popups_holder
        "SwimmingPool.instance"
      end

      def too_many_results?(view)
        find_card_numbers(view).size > CardViewLimits::MAX_GRID_VIEW_SIZE.to_i
      end

      def displaying_cards(view)
        lane_restricted_query(view).find_cards(:limit => (CardViewLimits::MAX_GRID_VIEW_SIZE.to_i + 1))
      end

      def displaying_card_count(view)
        lane_restricted_query(view).card_count
      end

      def find_card_numbers(view)
        view.group_lanes.visibles(:lane).map do |lane|
          lane.cards.map(&:number)
        end.flatten
      end

      def clear_not_applicable_params!(params)
        [:columns, :sort, :order, :page].each{|param| params.delete_ignore_case(param)}
      end

      def card_query_order_by(view)
        if view.grid_sort_by
          direction = 'desc' if view.grid_sort_by == 'number'
          [CardQuery::Column.new(view.grid_sort_by, direction)]
        else
          [CardQuery::Column.new('Project Card Rank')]
        end
      end

      def color_by_property_definition(view)
        view.group_lanes.color_by_property_definition
      end

      def current_page(view)
        nil
      end

      def to_s
        'grid'
      end

      private

      def lane_restricted_query(view)
        view.workspace.all_cards_query.restrict_with(view.group_lanes.lane_restriction_query)
      end
    end
  end
end
