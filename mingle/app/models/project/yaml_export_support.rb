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

class Project
  module YamlExportSupport

    def to_template
      self.activate
      project_spec = {
        'ordered_tab_identifiers' => ordered_tab_identifiers_spec,
        'card_types' => card_types_spec,
        'property_definitions' => property_definition_spec,

        'card_defaults' => card_defaults_spec,
        'plvs' => plv_spec,
        'trees' => tree_spec,
        'cards' => card_spec,
        'pages' => page_spec,
        'tabs' => tab_spec,
        'favorites' => favorite_spec
      }
      #converting to json and back to ensure the yaml content is not exported as Ruby object
      YAML::dump(JSON.parse(project_spec.to_json))
    end

    private
    def card_types_spec
      card_types.map do |ct|
        {'name' => ct.name, 'position' => ct.position, 'color' => ct.color, 'property_definitions' => ct.property_definitions.map{|pd| {'name' => pd.name}}}
      end
    end

    def ordered_tab_identifiers_spec
      Array(ordered_tab_identifiers).map do |id|
        r = if id =~ /^\d+$/
              tabs.find_by_id(id).try(:favorited)
            end
        r.try(:name) || id
      end
    end

    def tab_spec
      tabs.map do |tab|
        {'name' => tab.name}.merge(tab.to_params).tap do |h|
          h.delete(:favorite_id)
        end
      end
    end

    def favorite_spec
      favorites.inject([]) do |result, favorite|
        card_list_view = all_card_list_views.find(favorite.favorited_id)
        favorites_hash = {'name' => favorite.name}.merge(card_list_view.to_params)
        result << favorites_hash
      end
    end

    def page_spec
      pages.inject([]) do |result, page|
        page_hash = {}
        page_hash.merge! 'name' => page.name
        page_hash.merge! 'content' => page.content
        result << page_hash
      end
    end

    def card_spec
      result = {:numbers => Set.new, :cards => []}
      cards.all(:order => :number).each do |card|
        collect_card_hash(card, result)
      end
      result[:cards]
    end

    def collect_card_hash(card, result)
      return if result[:numbers].include?(card.number)

      card_hash = {}
      card_hash.merge! 'name' => card.name
      card_hash.merge! 'card_type_name' => card.card_type_name
      card_hash.merge! 'number' => card.number
      card_hash.merge! 'description' => card.description

      properties = card_properties_spec(card)
      if !properties.blank?
        card_hash.merge! 'properties' => properties
      end

      relationships = card_relationships_spec(card)
      if !relationships.blank?
        card_hash.merge! 'card_relationships' =>  relationships
        relationships.each do |name, number|
          if !result[:numbers].include?(number)
            collect_card_hash(cards.find_by_number(number), result)
          end
        end
      end

      result[:numbers] << card.number
      result[:cards] << card_hash
    end

    def card_relationships_spec(card)
      card.property_values_with_hidden.inject({}) do |prop_values, property|
        if property.value && property.property_definition.is_a?(TreeRelationshipPropertyDefinition)
          prop_values.merge!(property.name.downcase => property.value.number)
        end
        prop_values
      end
    end

    def card_properties_spec(card)
      card_properties = {}
      card.property_values_with_hidden.each do |property|
        if property.value && property.property_definition.type != "TreeRelationshipPropertyDefinition"
          v = if property.value.is_a?(User)
                PropertyType::UserType::CURRENT_USER
              else
                property.db_identifier
              end
          card_properties.merge!(property.name.to_s => v)
        end
      end
      card_properties
    end

    def tree_spec
      tree_configurations.map do |tree_configuration|
        aggregate_pds = tree_configuration.aggregate_property_definitions.map do |pd|
          {'name' => pd.name,
            'scope_card_type_name' => pd.aggregate_scope.try(:name),
            'type' => pd.aggregate_type.identifier,
            'card_type_name' => pd.aggregate_card_type.name,
            'target_property_name' => pd.target_property_definition.name,
            'condition' => pd.aggregate_condition}
        end
        {
          'name' => tree_configuration.name,
          'description' => tree_configuration.description,
          'configuration' => tree_configuration_hash(tree_configuration),
          'aggregate_properties' => aggregate_pds
        }
      end
    end

    def tree_configuration_hash(tree_configuration)
      tree_configuration.all_card_types.map do |card_type|
        relationship = tree_configuration.relationships.detect { |relationship| relationship['valid_card_type_id'] == card_type.id }
        config_hash = {
          'card_type_name' => card_type.name,
          'position' => tree_configuration.card_type_index(card_type)
        }
        config_hash.merge!('relationship_name' => relationship["name"]) if relationship
        config_hash
      end
    end

    def property_definition_spec
      res = []
      enum_property_definitions_with_hidden.each do |pd|
        res << property_values_hash(pd).merge('is_managed' => 'true',
                                              'property_value_details' => property_value_details_hash(pd))
      end
      text_property_definitions_with_hidden.each do |pd|
        res << property_values_hash(pd).merge('is_managed' => 'false')
      end

      [user_property_definitions_with_hidden,
       date_property_definitions_with_hidden,
       card_relationship_property_definitions_with_hidden,
       formula_property_definitions_with_hidden].each do |pds|
        pds.each do |pd|
          res << property_values_hash(pd)
        end
      end
      res
    end

    def property_values_hash(property_definition)
      {'name' => property_definition.name,
        'data_type' => property_definition.data_type}
    end

    def property_value_details_hash(pd)
      pd.values.map do |value|
        {'value' => value.value,
          'position' => value.position,
          'color' => value.color}
      end
    end

    def card_defaults_spec
      card_types.map(&:card_defaults).map do |card_default|
        {
          'description' => card_default.description,
          'card_type_name' => card_default.card_type.name,
          'properties' => card_default_properties(card_default)
        }
      end
    end

    def card_default_properties(card_default)
      property_names = card_default.property_definitions.map(&:name)
      property_names.inject({}) do |result, pn|
        result[pn] = card_default.property_value_for(pn).value
        result
      end
    end

    def plv_spec
      plv_types = { 'StringType' => 'STRING_DATA_TYPE',
                  'UserType' => 'USER_DATA_TYPE',
                  'NumericType' => 'NUMERIC_DATA_TYPE',
                  'DateType' => 'DATE_DATA_TYPE',
                  'CardType' => 'CARD_DATA_TYPE' }

      project_variables.map do |variable|
        plv_hash = {"name" => variable.name,
                    "property_definitions" => variable.property_definitions.map(&:name),
                    "data_type" => plv_types[variable.data_type]}

        if variable.data_type == ProjectVariable::CARD_DATA_TYPE
          plv_hash.merge!("card_type" => variable.card_type.name,
                          "value" => variable.value ? cards.find_by_id(variable.value).number : nil)
        else
          plv_hash.merge!("value" => variable.value)
        end
        plv_hash
      end
    end

  end
end
