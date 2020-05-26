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

module AutoTransition
  class Model
    def initialize(project, card, property_value, params)
      @project = project
      @card = card
      @property_value = property_value
      @params = params
    end

    def apply
      if no_property_value_changed?
        @card.rerank(@params[:rerank])
        return [:non_property_change]
      end

      if @property_value.transition_only?
        transitions = @card.transitions.select { |transition| transition.actions.any?{|participant| participant.uses?(@property_value) } }
        Transitions.new(@project, @card, transitions).apply
      else
        @property_value.assign_to(@card)

        if !@card.valid?
          return [:card_error]
        else
          view = CardListView.find_or_construct(@project, @params)
          old_lanes = view.group_lanes.visibles(:lane)
          old_rows = view.groups.visibles(:row)
          @card.save!
          return [:update_successfully, old_lanes, old_rows]
        end
      end
    end

    def no_property_value_changed?
      @property_value.assigned_to?(@card)
    end
  end
end
