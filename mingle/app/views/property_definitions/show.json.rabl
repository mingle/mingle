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
object @property_definition

instance = @property_definition || @object

cache Keys::PropertyDefinitionJSON.new.path_for(Project.current, instance, @include_property_values, @exclude_attrs)

all_attributes = instance.class.complete_attributes(instance, 'v2')
attributes_to_exclude = (@exclude_attrs || []) + [:project, :formula, :project_level_variable_options, :valid_card_type_name, :property_value_details]

attributes_to_serialize = all_attributes - attributes_to_exclude

attributes *attributes_to_serialize
attributes :operator_options, :tree_special?, :nullable?, :card_selector_filter_values_mql, :card_selector_filter_values_search_context, if: @include_property_values

child :property_value_details, if: all_attributes.include?(:property_value_details), root: :property_value_details do |property_value_details|
  collection property_value_details, object_root: false
  extends 'property_definitions/property_value_detail'
end

node :formula, if: all_attributes.include?(:formula) do |property_def|
  property_def.formula.to_s
end

node :project_level_variable_options, if: @include_property_values do |property_def|
  plv_options_for_droplist(property_def)
end

child :project do
  attributes :name, :identifier
end

node :valid_card_type_name, if: lambda { |property_def| property_def.respond_to?(:valid_card_type) } do |property_def|
  property_def.valid_card_type.name
end