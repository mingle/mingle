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

class VariableBinding < ActiveRecord::Base

  belongs_to :project_variable
  belongs_to :property_definition
  has_many :transition_actions, :dependent => :destroy

  attr_accessor :should_destroy
  
  def should_destroy?
    should_destroy
  end

  def property_value
    PropertyValue.create_from_db_identifier(property_definition, project_variable.value)
  end
  
  alias_method :derefer, :property_value
  
  def uses_enumeration_value?(property_definition, value)
    self.property_value == PropertyValue.create_from_db_identifier(property_definition, value)
  end
  
  def transitions
    property_definition.transitions.flatten.select{ |transition| transition.uses_project_variable?(project_variable) }
  end
  
  def card_list_views
    project.favorites_and_tabs.of_card_list_views.using(property_definition).select {|fav| fav.favorited.uses_plv?(project_variable)}.collect(&:favorited)
  end
  
  def project
    project_variable.project
  end
  
  def has_special_value?
    true
  end
  
  def set?
    true
  end
  
  def assign_to(card, options={})
    property_value.assign_to(card, options)
  end
  
  def display_value
    project_variable.display_name
  end
  
  def db_value_pair
    property_value.db_value_pair
  end
  
  alias_method :url_identifier, :display_value
  
  def sort_value
    self.display_value if(ProjectVariable.is_defined?(property_definition.project, ProjectVariable.extract_plv_name(self.display_value)))
  end
  
  alias_method :db_identifier, :display_value
  
  def computed_value
    property_value.computed_value
  end
  
  def value_equal?(property_value)
    property_value == self.property_value
  end
  
  def has_current_user_special_value?
    false
  end
  
  def ignored?
    false
  end
  
  def name
    property_definition.name
  end
  
  def hidden?
    property_definition.hidden?
  end

end
