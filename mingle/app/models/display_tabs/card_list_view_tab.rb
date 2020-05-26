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

require File.join(File.dirname(__FILE__), 'base_tab')

class DisplayTabs
  class CardListViewTab < UserDefinedTab

    def tab_type
      'CardListView'
    end

    def initialize(project, favorite, context, access_key=nil)
      super(project, favorite, access_key, "#{favorite.favorited.style}-tab")
      @context = context
    end

    def tree_name
      @target.favorited.tree_name.blank? ? CardContext::NO_TREE : @target.favorited.tree_name
    end

    def params
      @context.view_params_for(@target.name, self.tree_name)
    end

    def dirty?
      pristine_state = @target.favorited.canonical_string
      current_state = @context.canonical_tab_string_for(@target.name)

      return false if [pristine_state, current_state].all?(&:blank?)
      pristine_state != current_state
    end

    def rename(new_name)
      @target.favorited.update_attributes :name => new_name
    end

    def sidebar_text
      "Filters & Views"
    end
  end
end
