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

class PropertyDefinitionTransitionAction < TransitionAction
  belongs_to :property_definition, :foreign_key => "target_id"
  belongs_to :variable_binding
  
  def property_definition
    project.all_property_definitions.detect{|pd| pd.id == self.target_id}
  end
  memoize :property_definition

  def project
    Project.current
  end
  
  def execute(card, user_entered_properties={})
    card.without_transition_only_validation do
      target_property.assign_to(card)
    end
  end  
  
  def to_s
    "Sets #{display_name.bold} to #{display_value.bold}"
  end
  
  def uses_any_card?
    variable_binding_id.nil? && PropertyType::CardType === property_definition.property_type
  end
  
  def uses?(property)
    target_property.value_equal?(property)
  end

  def uses_property_definition?(property_definition)
    target_property.property_definition == property_definition
  end

  def uses_member?(property)
    return false if target_property.has_current_user_special_value?
    uses?(property)
  end
  
  def target_property
    variable_binding || PropertyValue.create_from_db_identifier(property_definition, value)
  end
  
  def target_property=(target)
    self.property_definition = target.property_definition
    if target.is_a? VariableBinding
      self.variable_binding = target
    else
      self.value = target.db_identifier
      self.variable_binding_id = nil
    end
  end
  
  def validate
    if !ProjectVariable.is_a_plv_name?(value)
      property_definition.validate_transition_action(self) if !target_property.has_special_value?
    else
      validate_attempt_to_create_plv(ProjectVariable.extract_plv_name(value))
    end
  end
  
  def validate_attempt_to_create_plv(plv_name)
    plv = ProjectVariable.find_plv_in_current_project(plv_name)
    if plv.nil? || !plv.property_definitions.include?(target_property.property_definition)
      errors.add_to_base(property_definition.attemped_to_create_plv(value))
    end
  end

  def sets_user_from_list?(users)
    users.any? { |user| includes_user?(user) }
  end
  
  def includes_user?(user)
    property_definition.is_a?(UserPropertyDefinition) && value.to_i == user.id
  end
  
  def uses_project_variable?(project_variable)
    return false unless variable_binding
    variable_binding.project_variable == project_variable
  end
  
  def display_value
    self.target_property.display_value
  end
  
  def display_name
    self.target_property.name
  end
end
