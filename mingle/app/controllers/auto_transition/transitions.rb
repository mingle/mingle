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
  class Transitions
    def initialize(project, card, transitions)
      @project = project
      @card = card
      @transitions = transitions
    end
    
    def apply
      if @transitions.size == 1
        @transition = @transitions.first
        if @transition.accepts_user_input?
          [:require_user_input, @transition]
        else
          execution = TransitionExecution.new(@project, :transition => @transition, :card => @card)
          execution.process
          if execution.errors.empty?
            [:transition_applied, @transition.name]
          else
            [:execution_error, @transition.name, execution.errors]
          end
        end
      elsif @transitions.size > 1
        [:multi_transitions_matched, @transitions]
      else
        [:no_transition_matched]
      end
    end
  end
end
