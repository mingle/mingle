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

class DataSeriesChartAggregateTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper
  
  def setup
    login_as_member
  end
  
  # bug 5823 - we were ordering alphabetically before
  def test_order_of_x_labels_for_an_aggregate_are_in_numeric_order
    with_filtering_tree_project do |project|
      tree_configuration = project.tree_configurations.find_by_name('planning tree')
      sum_of_iteration_size = project.find_property_definition('sum of iteration size')
      
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      iteration3 = project.cards.find_by_name('iteration3')
      
      iteration_size = project.find_property_definition('iteration size')
      iteration_size.update_card(iteration1, 5)
      iteration_size.update_card(iteration2, 5)
      iteration_size.update_card(iteration3, 9)
      [iteration1, iteration2, iteration3].each(&:save!)
      
      sum_of_iteration_size.update_cards
      AggregateComputation.run_once
      
      template = %{ {{
        data-series-chart
          cumulative: false
          series:
            - label       : Hello There
              data        : SELECT 'sum of iteration size', COUNT(*) WHERE Type = 'release'
      }} }
      
      chart = Chart.extract(template, 'data-series', 1)
      assert_equal ['9', '10'], chart.x_axis_values
      assert_equal [1, 1], chart.series_by_label['Hello There'].values
    end
  end
  
end
