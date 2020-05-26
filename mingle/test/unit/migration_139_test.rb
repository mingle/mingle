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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../db/migrate/139_remove_formula_properties_that_use_aggregates.rb')

class Migration139Test < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def test_only_formulas_using_aggregates_will_be_deleted
    # login_as_admin
    # create_tree_project(:init_three_level_tree) do |project, tree, config|
    #   type_release, type_iteration, type_story = find_planning_tree_types
    #   
    #   setup_text_property_definition('textomatic')
    #   setup_numeric_property_definition('size', [1, 2, 3])
    #   setup_formula_property_definition('size plus one', 'size + 1')
    #   setup_aggregate_property_definition('count of children', AggregateType::COUNT, nil, config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
    #   setup_aggregate_property_definition('count of stories', AggregateType::COUNT, nil, config.id, type_release.id, type_story)
    #   setup_formula_property_definition('count of children plus one', "'count of children' + 1")
    #   setup_formula_property_definition('more complicated one', "5 + ('count of stories'-3) / (('size'))")
    #   setup_formula_property_definition('another complicated one', "(3 / ('count of children') + 1) * size")
    #   assert_equal ['Planning iteration', 
    #                 'Planning release',
    #                 'another complicated one',
    #                 'count of children',
    #                 'count of children plus one', 
    #                 'count of stories',
    #                 'more complicated one',
    #                 'size', 
    #                 'size plus one', 
    #                 'textomatic'], project.reload.all_property_definitions.collect(&:name).sort
    #   RemoveFormulaPropertiesThatUseAggregates.up
    #   project.reload
    #   assert_equal ['Planning iteration', 
    #                 'Planning release',
    #                 'count of children',
    #                 'count of stories',
    #                 'size',
    #                 'size plus one', 
    #                 'textomatic'], project.reload.all_property_definitions.collect(&:name).sort
    # end
  end
end
