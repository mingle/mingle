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

module MingleModelLoaders
  class CardTypesPropertyDefinitionsLoader
    def initialize(card_type_or_property_definition)
      @card_type_or_property_definition = card_type_or_property_definition
    end

    def load
      if @card_type_or_property_definition.respond_to?(:is_predefined) && @card_type_or_property_definition.is_predefined  #pre_defined_property
        @card_type_or_property_definition.project.with_active_project do |project|
          project.card_types.collect do |card_type|
            ct = CardTypeLoader.new(card_type)
            pd = PropertyDefinitionLoader.new(@card_type_or_property_definition)
            OpenStruct.new(:card_type => ct.load, :property_definition => pd.load)
          end
        end
      else
        @card_type_or_property_definition.property_type_mappings.collect do |mapping|
          ct = CardTypeLoader.new(mapping.card_type)
          pd = PropertyDefinitionLoader.new(mapping.property_definition)
          OpenStruct.new(:card_type => ct.load, :property_definition => pd.load)
        end
      end
    end
  end
end
