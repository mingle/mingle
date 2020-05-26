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
    class List < Base
      def displaying_cards(view)
        view.workspace.all_cards_query.find_cards(view.pagination_options)
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
  
      def describe_current_page(view)
        "Listed below: #{view.first_item_in_current_page} to #{view.last_item_in_current_page} of #{view.all_cards_size}."
      end
  
      def current_page(view)
        view.page
      end
  
      def to_s
        'list'
      end

      def popups_holder
        "FakePool()"
      end
    end
  end
end
