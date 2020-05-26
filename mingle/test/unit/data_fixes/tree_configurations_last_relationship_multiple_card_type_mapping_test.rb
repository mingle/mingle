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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class TreeConfigurationsLastRelationshipMultipleCardTypeMappingTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_admin
    @project = create_project
    @project.activate
    configuration = @project.tree_configurations.create!(:name => 'Planning')
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    init_three_level_tree(configuration)
    @original_card_types = configuration.reload.relationships.last.card_types

    # Adding the additional property type mapping on the tree configuration that needs to be fixed
    relationship = configuration.reload.relationships.last
    relationship.property_type_mappings.create(:card_type => @type_iteration)

    @second_project = create_project
    @second_project.activate
    init_planning_tree_types
    configuration = @second_project.tree_configurations.create!(:name => 'Another_planning_tree')
    init_five_level_tree(configuration)
  end

  def test_applying_fix_will_fix_error_on_multiple_card_mappings_for_the_last_tree_configurations_property_definition
    assert_raise(RuntimeError) do
      @project.with_active_project do |project|
        project.tree_configurations.find_by_name('Planning').relationship_map.card_types
      end
    end
    assert DataFixes::TreeConfigurationsLastRelationshipMultipleCardTypeMapping.required?

    DataFixes::TreeConfigurationsLastRelationshipMultipleCardTypeMapping.apply

    assert_false DataFixes::TreeConfigurationsLastRelationshipMultipleCardTypeMapping.required?
    assert_nothing_raised do
      @project.reload.with_active_project do |project|
        configuration = project.tree_configurations.find_by_name('Planning')
        configuration.relationship_map.card_types
        assert_equal @original_card_types, configuration.relationships.last.card_types
      end
    end
  end

end
