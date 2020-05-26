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
require File.expand_path(File.dirname(__FILE__) + '/../messaging_test_helper')

class FormulaAggregateTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    @project = create_project
    @project.activate
    login_as_member
  end

  def test_changing_a_formula_results_in_aggregate_recalculation
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      formula_property = setup_formula_property_definition('formula def', '1 + 9')
      type_story.add_property_definition(formula_property)
      type_story.save!

      iteration_size = setup_aggregate_property_definition('size',
                                                            AggregateType::SUM,
                                                            formula_property,
                                                            configuration.id,
                                                            type_iteration.id,
                                                            AggregateScope::ALL_DESCENDANTS)

      iteration_size.update_cards
      AggregateComputation.run_once

      iteration1 = project.cards.find_by_name('iteration1')
      assert_equal 20, iteration_size.value(iteration1)

      formula_property.change_formula_to("1 + 99")
      formula_property.save!

      AggregateComputation.run_once
      assert_equal 200, iteration_size.value(iteration1.reload)
    end
  end



  # bug 3058
  def test_changes_for_formula_properties_will_describe_dates_properly
    with_project_without_cards do |project|
      card = create_card!(:name => 'some card', :startdate => '16 Mar 2008')
      project.find_property_definition('day after start date').change_formula_to('1 + 2')
      HistoryGeneration.run_once
      project.all_property_definitions.reload

      assert_equal "day after start date changed from 17 Mar 2008 to 3", card.versions.last.describe_changes.first
    end
  end

end
