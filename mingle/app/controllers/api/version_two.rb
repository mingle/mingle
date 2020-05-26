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

module API
  class VersionTwo
  
    class CardsControllerAPIDelegate
      attr_reader :params

      def initialize(project, params)
        @project, @params = project, params
      end

      def card_properties
        return {} unless params[:card] && params[:card][:properties]
        property_definitions = @project.all_property_definitions
        properties = {}
        params[:card][:properties].each do |property_name_value_hash|
          if property_definition = property_definitions.detect { |pd| pd.name.downcase == property_name_value_hash[:name].downcase }
            property_value = PropertyValue.create_from_url_identifier(property_definition, property_name_value_hash[:value])
            properties[property_name_value_hash[:name]] = property_value.db_identifier
          else
            properties[property_name_value_hash[:name]] = property_name_value_hash[:value]
          end
        end  
        properties
      end
      
      def find_card
        @project.cards.find_by_number(params[:number])
      end
      
    end
  end
end
