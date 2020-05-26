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

module DataFixes
  class TreeConfigurationsLastRelationshipMultipleCardTypeMapping < Base

    def self.description
      %{ This data fix is for removing multiple card type mappings on the last relationship in a tree configuration.
       The last TreeConfigurationPropertyDefinition type mapping added to the relationships on a tree configuration should have only one
       card type mapping. }
    end

    def self.required?
      tree_configurations_with_incorrect_last_relationship.any?
    end

    def self.apply(project_ids=[])
      tree_configurations_with_incorrect_last_relationship.each do |tree_config|
        Project.find(tree_config.project_id).with_active_project do |project|
          property_mappings = tree_config.relationships.last.property_type_mappings.sort! {|a, b| a.id <=> b.id}
          if property_mappings.size > 1
            property_mappings[1..-1].each { |mapping| mapping.destroy }
          end

          project.reload.card_types.each do |card_type|
            tree_property_definitions = card_type.property_definitions.select { |pdef| pdef.instance_of?(TreeRelationshipPropertyDefinition) }
            tree_property_definitions.each do |t_prop_def|
              if !t_prop_def.tree_configuration.include_card_type?(card_type)
                PropertyTypeMapping.find(:first, :conditions => {:card_type_id => card_type.id, :property_definition_id => t_prop_def.id}).destroy
              end
            end
          end
        end
      end
    end

    private
    def self.tree_configurations_with_incorrect_last_relationship
      tree_configs = []
      Project.all.each do |project|
        project.with_active_project do |project|
          project.tree_configurations.each do |tree_config|
            tree_configs << tree_config if tree_config.relationships.last.card_types.size > 1
          end
        end
      end
      tree_configs
    end
  end
end
