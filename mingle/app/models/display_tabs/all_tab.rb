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

class DisplayTabs
  class AllTab < PredefinedTab
    NAME = 'All'

    def name
      NAME
    end

    def self.all_cards_card_list_view_for(project)
      CardListView.construct_from_params(project, {:name => NAME})
    end

    def initialize(project, context={})
      super(project, "a", "list-tab")
      @context = context
    end

    def params
      @context.view_params_for(name, CardContext::NO_TREE)
    end

    def dirty?
      pristine_state = view.canonical_string
      current_state = @context.canonical_tab_string_for(name)
      return false if [pristine_state, current_state].all?(&:blank?)
      pristine_state != current_state
    end

    def view
      @view ||= AllTab.all_cards_card_list_view_for(@project)
    end

    def sidebar_text
      "Filters & Views"
    end
  end
end
