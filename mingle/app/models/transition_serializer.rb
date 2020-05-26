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

class TransitionSerializer
   include API::XMLSerializer
   
   serializes_as :complete => [:id, :name, :require_comment?, :transition_execution_url, :user_input_required, :user_input_optional, :if_card_has_properties, :if_card_has_properties_set, :will_set_card_properties], :element_name => 'transition'
   conditionally_serialize :only_available_for_users, :if => Proc.new {|transition_serializer| transition_serializer.transition.has_user_prerequisites? }
   conditionally_serialize :only_available_for_groups, :if => Proc.new {|transition_serializer| transition_serializer.transition.has_group_prerequisites? }
   conditionally_serialize :card_type, :if => Proc.new { |transition_serializer| transition_serializer.card_type }
   conditionally_serialize :to_remove_from_trees_with_children, :if => Proc.new { |transition_serializer| transition_serializer.to_remove_from_trees_with_children.any? }
   conditionally_serialize :to_remove_from_trees_without_children, :if => Proc.new { |transition_serializer| transition_serializer.to_remove_from_trees_without_children.any? }

   delegate :id, :name, :require_comment?, :card_type, :to => :@transition
   attr_reader :transition
   
   def initialize(transition)
     @transition = transition
   end

   def user_input_optional
     @transition.accepts_user_input_property_definitions - @transition.require_user_to_enter_property_definitions    
   end

   def transition_execution_url(options)
     view_helper = options[:view_helper]
     view_helper.send(:rest_transition_execution_create_v2_url, :project_id => @transition.project.identifier, :id => self.id)
   end

   def user_input_required
     @transition.require_user_to_enter_property_definitions
   end

   def if_card_has_properties
     (@transition.required_properties - has_value_set_prerequisite_values).collect(&:derefer)
   end
   
   def if_card_has_properties_set
     has_value_set_prerequisite_values.collect(&:property_definition)
   end
   
   def will_set_card_properties
     result = @transition.target_properties.reject do |property|
       property.property_definition.is_a? TreeBelongingPropertyDefinition
     end
     
     result.reject! do |property|
       Transition::USER_INPUT_VALUES.include?(property.db_identifier)
     end

     result.collect(&:derefer)
   end 

   def only_available_for_users
     @transition.used_by_user
   end
   
   def only_available_for_groups
    @transition.used_by_group
   end
   
   def to_remove_from_trees_with_children
     remove_from_tree_properties = @transition.target_properties.select do |property|
       property.db_identifier == TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE
     end

     remove_from_tree_properties.collect { |property| API::SerializableString.new(property.tree_name, 'tree_name') }
   end

   def to_remove_from_trees_without_children
     remove_from_tree_properties = @transition.target_properties.select do |property|
       property.db_identifier == TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE
     end

     remove_from_tree_properties.collect { |property| API::SerializableString.new(property.tree_name, 'tree_name') }
   end
   
   private
   
   def has_value_set_prerequisite_values
     @transition.required_properties.select do |property_value|
        PropertyValueSet === property_value
      end
   end

end

