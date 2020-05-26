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

class TreePropertyInMacroAggregateTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include MessagingTestHelper
  
  def setup
    login_as_member
    @project = three_level_tree_project
    @project.activate
    @config = @project.tree_configurations.first
    @iteration1 = @project.cards.find_by_name('iteration1')
    @iteration2 = @project.cards.find_by_name('iteration2')
  end
    
  def test_aggregate_property
    @project.deactivate rescue nil
    create_planning_tree_project do |project, tree, config|
      project.add_member(User.current)
      @project = project
      @config = config
      @type_release = @project.card_types.find_by_name('release')
      options = { :name => 'aggregate prop def', 
                  :aggregate_scope =>AggregateScope::ALL_DESCENDANTS, 
                  :aggregate_type => AggregateType::COUNT, 
                  :aggregate_card_type_id => @type_release.id, 
                  :tree_configuration_id => @config.id }

      agg_property = @project.property_definitions_with_hidden.create_aggregate_property_definition(options)
      @project.reload.update_card_schema

      agg_property.update_cards
      AggregateComputation.run_once
    
      template = %{  {{
        data-series-chart
          series:
            - label       : AggCountSize
              data        : SELECT 'aggregate prop def', COUNT(*)
      }} }
      chart = Chart.extract(template, 'data-series-chart', 1)
      chart_options = JSON.parse(chart.generate)
      data_series_point_chart_options = {'show' =>false, 'symbols' =>{}, 'focus' =>{'expand' =>{'enabled' =>false}}}
      data_series_tooltip_chart_options = {'grouped' => false}
      assert_equal ['4'], chart.x_axis_values
      assert_equal [1], chart.series_by_label['AggCountSize'].values
      assert_equal data_series_point_chart_options, chart_options['point']
      assert_equal data_series_tooltip_chart_options, chart_options['tooltip']

    end
  end
end
