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
object @card_type

cache Keys::CardTypeJSON.new.path_for(Project.current, @card_type || @object, @include_property_values)

attributes :id, :name, :color, :position

prop_def_locals = @include_property_values ?  {exclude_attrs: [:card_types]} : {}
prop_def_partial = @include_property_values ? 'property_definitions/index.json' : 'property_definitions/show_compact'

child property_definitions_with_hidden: :property_definitions do |property_definitions|
  collection property_definitions, object_root: false
  extends prop_def_partial, locals: prop_def_locals
end
