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

class PropertyTypeMapping < ActiveRecord::Base
  belongs_to :card_type
  belongs_to :property_definition
  acts_as_list :scope => :card_type
  validates_uniqueness_of :property_definition_id, :scope => [:card_type_id]
  after_create :compute_formulas_if_necessary
  before_destroy :remove_history_subscriptions
  
  def project
    Project.current
  end

  def property_definition
    project.property_definitions_with_hidden.detect {|pd| pd.id == self.property_definition_id}
  end
  
  def card_type
    project.find_card_type_by_id(self.card_type_id)
  end
  
  def serialize_lightweight_attributes_to(serializer)
    serializer.card_type_property_definition do
      serializer.card_type_id card_type_id
      serializer.property_definition_id property_definition_id
      serializer.position position
    end
  end  
  
  private
  
  def remove_history_subscriptions
    project.history_subscriptions.each do |subscription|
      involved = subscription.involved_filter_properties.uses_card_type_and_property?(card_type, property_definition)
      acquired = subscription.acquired_filter_properties.uses_card_type_and_property?(card_type, property_definition)
      subscription.destroy if involved || acquired
    end
  end
  
  def compute_formulas_if_necessary
    project.property_definitions_with_hidden.reload
    return unless associating_card_type_with_existing_formula_property_definition?
    property_definition.reload.update_all_cards_of_type(card_type)
  end
  
  def associating_card_type_with_existing_formula_property_definition?
    self.property_definition.formulaic? && !self.property_definition.new_record? && Card.column_names.include?(self.property_definition.column_name)
  end
end
