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

class TransitionAction < ActiveRecord::Base
  belongs_to :executor, :polymorphic => true
  
  class << self
    def new_property_definition_transition_action(options)
      require_user_to_enter = options.delete(:require_user_to_enter)
      user_input_optional = options.delete(:user_input_optional)
      
      if require_user_to_enter
        UserInputRequiredTransitionAction.new(options)
      elsif user_input_optional
        UserInputOptionalTransitionAction.new(options)
      else
        PropertyDefinitionTransitionAction.new(options)
      end
    end
  end
  
  def value
    return nil if attributes['value'].blank?
    attributes['value']
  end
  
  def uses_any_card?
    false
  end
  
  def uses_tree?(tree_configuration)
    false
  end
  
  def uses_project_variable?(project_variable)
    false
  end
  
  #user input required action & user input input optional action
  def accepts_user_input?
    false
  end
  
  def require_user_to_enter
    false
  end
  
  def uses_member?(property)
    false
  end
end
