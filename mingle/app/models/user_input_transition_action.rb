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

module UserInputTransitionAction
  
  def execute(card, user_entered_properties={})
    return unless user_entered_properties.keys.collect(&:downcase).include?(property_definition.name.downcase)
    db_identifier = user_entered_properties.find_ignore_case(property_definition.name)
    property_value_to_set = property_definition.property_value_from_db(db_identifier)
    card.without_transition_only_validation do
      property_value_to_set.assign_to(card)
    end
  end
  
  def accepts_user_input?
    true
  end
  
  def value
    nil
  end
  
  def uses?(property_value)
    property_value.property_definition == self.property_definition && property_value.db_identifier == special_value
  end
  
  def target_property
    PropertyValue.create_from_db_identifier(property_definition, special_value)
  end
  
  
end
