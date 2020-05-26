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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class TreePropertyInMacroTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include RenderableTestHelper::Unit
  def setup
    login_as_member
    @project = three_level_tree_project
    @project.activate
    @config = @project.tree_configurations.first
    @iteration1 = @project.cards.find_by_name('iteration1')
    @iteration2 = @project.cards.find_by_name('iteration2')
  end

  #bug 3804
  def test_tree_property_value_should_be_card_number_and_name_in_table_macro
    template = %{  {{
      table query: SELECT 'Planning iteration'
    }} }
    expected = %{
      <table>
        <tr>
          <th>Planning iteration</th>
        </tr>
        <tr>
          <td><a href="/projects/#{@project.identifier}/cards/#{@iteration1.number}" card_name_url="/projects/#{@project.identifier}/cards/card_name/#{@iteration1.number}" class="card-link-#{@iteration1.number}" onmouseover="new CardTooltip(this, event)">##{@iteration1.number}</a> iteration1</td>
        </tr>
        <tr>
          <td><a href="/projects/#{@project.identifier}/cards/#{@iteration1.number}" card_name_url="/projects/#{@project.identifier}/cards/card_name/#{@iteration1.number}" class="card-link-#{@iteration1.number}" onmouseover="new CardTooltip(this, event)">##{@iteration1.number}</a> iteration1</td>
        </tr>
        <tr>
          <td>&nbsp;</td>
        </tr>
        <tr>
          <td>&nbsp;</td>
        </tr>
        <tr>
          <td>&nbsp;</td>
        </tr>
      </table>
    }
    doc = REXML::Document.new expected
    assert_equal 'Planning iteration', doc.element_text_at('/table/tr[1]/th')
    assert_equal "##{@iteration1.number}", doc.element_text_at('/table/tr[2]/td/a')
    assert_equal ' iteration1', doc.element_text_at('/table/tr[2]/td')   # Needs the space. e.g. <td>#123 iteration1</td>
  end

  def test_tree_property_value_link_for_cross_project_table_macro
    login_as_admin
    story1 = @project.cards.find_by_name('story1')
    with_new_project do |proj|
      template = %{  {{
        table
          query: SELECT 'Planning iteration' where number is #{story1.number}
          project: 'three_level_tree_project'
      }} }
      output = render(template, proj, :preview => true)
      assert_equal "/projects/three_level_tree_project/cards/#{@iteration1.number}", get_attribute_by_xpath(output, '//table/tbody/tr/td/a/@href')
    end
  end

  def test_card_property_value_link_for_cross_project_table_macro
    login_as_admin
    with_new_project do |proj|
      setup_card_relationship_property_definition('card')
      card1 = create_card!(:name => 'card1')
      card2 = create_card!(:name => 'card2', :card => card1.id)
      @proj_identifier, @card1_number = proj.identifier, card1.number
    end
    template = %{  {{
      table
        query: SELECT card
        project: '#{@proj_identifier}'
    }} }
    output = render(template, @project, :preview => true)
    assert_equal "/projects/#{@proj_identifier}/cards/#{@card1_number}", get_attribute_by_xpath(output, '//table/tbody/tr/td/a/@href')
  end

  def test_tree_relationship_property_in_ratio_bar_chart_restrict_ratio_with_numeric_enum_prop
    template = %{  {{
      ratio-bar-chart:
        totals: SELECT 'Planning iteration', SUM(Size)
        restrict-ratio-with: 'size' > 2
    }} }
    chart = Chart.extract(template, 'ratio-bar-chart', 1)
    expected_default_y_axis_params = {'min' => 0, 'max' => 100,
                                      'tick' => {'format' => ''},
                                      'padding' => {'top' => 5, 'bottom' => 0},
                                      'label' => {'text' => '', 'position' => 'outer-middle'}}

    chart_options = JSON.parse(chart.generate)

    assert_equal [@iteration1.number_and_name], chart.labels
    assert_equal [75], chart.data #3/4 = 75%
    assert_equal expected_default_y_axis_params, chart_options['axis']['y']
    assert_equal 'bar', chart_options['data']['type']
  end

  def test_tree_relationship_property_in_pie_chart
    template = %{  {{
      pie-chart
        data: SELECT 'Planning iteration', SUM(Size)
    }} }
    chart = Chart.extract(template, 'pie-chart', 1)
    #not set means: the sum of size of story which is not in any iteration
    assert_equal [[@iteration1.number_and_name, 4], ['(not set)', 0]], chart.data

    assert_equal( 'pie', JSON.parse(chart.generate)['data']['type'])
  end

  def test_tree_relationship_property_in_data_series_chart
    template = %{  {{
      data-series-chart
        series:
          - label       : IterationSize
            data        : SELECT 'Planning Iteration', SUM(Size)
    }} }
    chart = Chart.extract(template, 'data-series-chart', 1)
    chart_options = JSON.parse(chart.generate)
    data_series_point_chart_options = {'show' =>false, 'symbols' =>{}, 'focus' =>{'expand' =>{'enabled' =>false}}}
    data_series_tooltip_chart_options = {'grouped' => false}

    assert_equal [@iteration1.number_and_name, @iteration2.number_and_name], chart.labels_for_plot
    assert_equal [4, 0], chart.series_by_label['IterationSize'].values
    assert_equal data_series_point_chart_options, chart_options['point']
    assert_equal data_series_tooltip_chart_options, chart_options['tooltip']
  end

  #bug 3664
  def test_should_display_blank_chart_when_the_conditions_filtered_all_data
    template = %{  {{
      data-series-chart
        x-title: Iterations
        y-title: Total Story Points
        data-point-symbol: diamond
        data-labels: true
        cumulative: true
        chart-height: 500
        chart-width: 800
        plot-height: 375
        plot-width: 500
        x-labels-conditions: 'Planning Release' = 'Cake'
        series:
        - label: Total Scope over iterations
          color: black
          type: line
          trend: true
          trend-line-width: 2
          data: SELECT 'Planning Iteration', SUM('Size')
    }} }
    chart = Chart.extract(template, 'data-series-chart', 1)
    chart_options = JSON.parse(chart.generate)
    data_series_point_chart_options = {'show' => false, 'symbols' =>{'Total Scope over iterations' => 'diamond'}, 'focus' =>{'expand' => {'enabled' => false}}}
    data_series_tooltip_chart_options = {'grouped' => false}

    assert_equal [], chart.x_axis_values
    assert_equal [], chart.series_by_label['Total Scope over iterations'].values
    assert_equal data_series_point_chart_options, chart_options['point']
    assert_equal data_series_tooltip_chart_options, chart_options['tooltip']
  end

  def test_tree_relationship_property_in_stack_bar_chart
    template = %{  {{
      stack-bar-chart
        series:
          - label: 'Planning iteration'
            color: Yellow
            data: SELECT 'Planning iteration', SUM(Size)
    }} }
    chart = Chart.extract(template, 'stack-bar', 1)
    assert_equal [@iteration1.number_and_name, @iteration2.number_and_name], chart.labels_for_plot
    assert_equal [4, 0], chart.series_by_label['Planning iteration'].values

    # everything still blows up here with invalid SQL
    chart_data = JSON.parse(chart.generate)
    assert_equal 'Planning iteration', chart_data['axis']['x']['label']['text']
    assert_equal 'Sum size', chart_data['axis']['y']['label']['text']
    assert_equal 0.85, chart_data['bar']['width']['ratio']
  end
end
