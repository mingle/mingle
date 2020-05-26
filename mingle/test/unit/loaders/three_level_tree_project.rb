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
  class ThreeLevelTreeProject
    include TreeFixtures::PlanningTree

    def execute
      UnitTestDataLoader.delete_project('three_level_tree_project')
      Project.create!(:name => 'three_level_tree_project', :identifier => 'three_level_tree_project', :corruption_checked => true).with_active_project do |project|
        project.generate_secret_key!
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)

        @configuration = project.tree_configurations.create(:name => 'three level tree')
        init_planning_tree_types
        init_three_level_tree(@configuration)

        @type_story = project.card_types.find_by_name("story")
        @type_iteration = project.card_types.find_by_name("iteration")

        UnitTestDataLoader.setup_card_relationship_property_definition('related card')
        UnitTestDataLoader.setup_property_definitions :status => ['open', 'closed']
        project.reload
        project.find_property_definition('status').card_types = [@type_iteration, @type_story]
        project.find_property_definition('related card').card_types = [@type_story]

        UnitTestDataLoader.setup_numeric_property_definition("size", [1, 2, 3, 4])
        UnitTestDataLoader.setup_user_definition("owner")
        project.reload
        size = project.find_property_definition('size')
        owner = project.find_property_definition('owner')
        @type_story.reload.add_property_definition(size)
        @type_story.reload.add_property_definition(owner)

        project.cards.find_by_name("story1").update_attribute(:cp_size, 1)
        project.cards.find_by_name("story2").update_attribute(:cp_size, 3)

        options = { :name => 'Sum of size',
                    :aggregate_scope => @type_story,
                    :aggregate_type => AggregateType::SUM,
                    :aggregate_card_type_id => @type_iteration.id,
                    :tree_configuration_id => @configuration.id,
                    :target_property_definition => size.reload
                  }
        @sum_of_size = project.all_property_definitions.create_aggregate_property_definition(options)
        project.reload.update_card_schema
        @sum_of_size.update_cards
        project.reset_card_number_sequence
      end
    end

  end
end
