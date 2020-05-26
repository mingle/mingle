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

require File.expand_path(File.dirname(__FILE__) + '../../../../unit_test_helper')

class PieChartMacroParamsTest < ActiveSupport::TestCase
  def setup
    login_as_member
    @project = pie_chart_test_project.activate
  end

  test 'should_extract_data_query' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10 AND TAGGED WITH "blah"'
    }.with_indifferent_access
    EasyCharts::ChartMql.expects(:from).with {|card_query| CardQuery.parse(macro_params[:data]).to_s == card_query.to_s}.returns(:ok)
    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal :ok, pie_chart_macro_params.data
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_not_support_in_easy_chart_when_data_mql_is_not_supported_by_easy_charts_form' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10 OR TAGGED WITH "tag"'
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_nil pie_chart_macro_params.data
    assert_false pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_chart_size_from_macro' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        'chart-size' => 'large'
    }
    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal('large', pie_chart_macro_params.chart_size)
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_chart_size_from_predefined_height_and_width_in_macro' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        'chart-height' => 600,
        'chart-width' => 880
    }

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal('large', pie_chart_macro_params.chart_size)
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_give_higher_priority_to_chart_size' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        'chart-size' => 'medium',
        'chart-height' => 600,
        'chart-width' => 880,
        radius: 500
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal('medium', pie_chart_macro_params.chart_size)
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_not_be_supported_in_easy_charts_when_height_and_width_given_does_not_match_with_any_predefined_values' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        'chart-height' => 500,
        'chart-width' => 880
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_false pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_not_be_supported_in_easy_charts_when_only_radius_is_given' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        radius: 500
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_false pie_chart_macro_params.supported_in_easy_charts?
    end

  test 'should_not_be_supported_in_easy_charts_when_property_does_not_exist' do
    macro_params = {
        data: 'Select InvalidProp, count(*) Where Type = "Card" AND Size < 10',
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_false pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_not_be_supported_in_easy_charts_when_card_type_does_not_exist' do
    macro_params = {
      data: 'Select Size, count(*) Where Type = "InvalidType" AND Size < 10',
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_false pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_legend_position' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        'legend-position' => 'right'
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal 'right', pie_chart_macro_params.legend_position
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_label_type' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        'label-type' =>  'whole-number'
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal 'whole-number', pie_chart_macro_params.label_type
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_chart_title' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "Card" AND Size < 10',
        title: 'Fantastic Chart'
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal 'Fantastic Chart', pie_chart_macro_params.title
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_project' do
    other_project = three_level_tree_project
    macro_params = {
        data: 'Select Size, count(*) Where Type = "story" AND Size < 10',
        project: other_project.identifier
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal other_project.identifier, pie_chart_macro_params.project
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_project_as_current_project_identifier_by_default' do
    macro_params = {
        data: 'Select Size, count(*) Where Type = "card" AND Size < 10',
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal @project.identifier, pie_chart_macro_params.project
    assert pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_project_when_project_does_not_exist_and_should_not_be_supported_in_easy_charts' do
    project_identifier = 'some_random_project'
    macro_params = {
        data: 'Select Size, count(*) Where Type = "story" AND Size < 10',
        project: project_identifier
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal project_identifier, pie_chart_macro_params.project
    assert_false pie_chart_macro_params.supported_in_easy_charts?
  end

  test 'should_extract_project_when_user_does_not_have_access_to_project_and_should_not_be_supported_in_easy_charts' do
    project_identifier = 'some_random_project'
    project = create_project(prefix: project_identifier)
    macro_params = {
        data: 'Select Size, count(*) Where Type = "story" AND Size < 10',
        project: project.identifier
    }.with_indifferent_access

    pie_chart_macro_params = EasyCharts::PieChartMacroParams.from(macro_params)

    assert_equal project.identifier, pie_chart_macro_params.project
    assert_false pie_chart_macro_params.supported_in_easy_charts?
  end
end
