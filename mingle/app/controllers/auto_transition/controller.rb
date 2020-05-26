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
  class Controller
    def initialize(controller, card)
      @controller = controller
      @card = card
    end

    def apply
      if params[:group_by].blank? || params[:group_by]["lane"].blank?
        @card.rerank(params[:rerank])
        return View.new(@controller, @card, nil).non_property_change
      end
      @project = @controller.project
      @property_value = nil
      render_target = if @selected_auto_transition = @card.transitions.detect{|transition| transition.id.to_s == params[:selected_auto_transition_id]}
        Transitions.new(@project, @card, [@selected_auto_transition]).apply
      else
        property = params[:group_by]['lane'] || params[:group_by]['row']
        @property_def = @project.find_property_definition(property)
        @property_value = @property_def.property_value_from_db(params[:value])
        Model.new(@project, @card, @property_value, params).apply
      end
      View.new(@controller, @card, @property_value).send(*render_target)
    end

    def params
      @controller.params
    end
  end
end
