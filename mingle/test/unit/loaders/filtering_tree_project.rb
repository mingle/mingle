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

module Loaders
  class FilteringTreeProject
    include TreeFixtures::PlanningTree 
   
    def execute
      UnitTestDataLoader.delete_project('filtering_tree_project')
      Project.create!(:name => 'filtering_tree_project', :identifier => 'filtering_tree_project', :corruption_checked => true).with_active_project do |project|
        project.generate_secret_key!
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)
        configuration = project.tree_configurations.create(:name => 'filtering tree')
        init_planning_tree_types
        tree = init_five_level_tree(configuration)
        
        type_story = project.card_types.find_by_name("story")
        type_iteration = project.card_types.find_by_name("iteration")
        type_release = project.card_types.find_by_name("release")

        UnitTestDataLoader.setup_property_definitions :workstream => ['x1', 'x2', 'x3'], :quick_win => ['yes', 'no'], :status => ['open', 'closed']
        project.reload.find_property_definition('workstream').card_types = [type_release]
        project.find_property_definition('quick_win').card_types = [type_iteration]
        project.find_property_definition('status').card_types = [type_release, type_iteration]
        
        UnitTestDataLoader.setup_numeric_property_definition('release size', [1, 2, 3])
        project.reload.find_property_definition('release size').card_types = [type_release]
        UnitTestDataLoader.setup_numeric_property_definition('iteration size', [1, 2, 3])
        project.reload.find_property_definition('iteration size').card_types = [type_iteration]
        UnitTestDataLoader.setup_numeric_property_definition('story size', [1, 2, 3])
        project.reload.find_property_definition('story size').card_types = [type_story]
        
        options = { :name => 'sum of iteration size',
                    :aggregate_scope => type_iteration,
                    :aggregate_type => AggregateType::SUM,
                    :aggregate_card_type_id => type_release.id,
                    :tree_configuration_id => configuration.id,
                    :target_property_definition => project.find_property_definition('iteration size').reload
                  }
        sum_of_size = project.all_property_definitions.create_aggregate_property_definition(options)
        project.reload.update_card_schema
        sum_of_size.update_cards
        
        project.reset_card_number_sequence
      end
      
    end
    
  end
end
