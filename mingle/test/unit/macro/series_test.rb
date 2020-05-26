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
require 'ostruct'

class SeriesTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit    
  def setup
    login_as_member
    @project = data_series_chart_project
    @project.activate
    
    @chart = OpenStruct.new
    @chart.project = @project
    @chart.x_axis_values = @project.find_property_definition('Development Complete Iteration').values.collect(&:name)
    @chart.trend_line_style = 'dash'
    @chart.trend_ignore = Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE
    @chart.trend_scope = Series::TREND_SCOPE_ALL
    @chart.trend_line_width = 3
    @chart.trend_line_color = -1
    @chart.trend = false
    @chart.data_point_symbol = 'none'
    @chart.data_labels = false
    @chart.line_width = 3
    @chart.line_style = 'solid'
    def @chart.cumulative?
      false
    end
    @chart.x_axis_labels = XAxisLabels.new(@project.find_property_definition('Development Complete Iteration'))
    
    @series_spec = {}
    @series_spec['data'] = %{SELECT 'Development Complete Iteration', SUM(Size)}
    @series_spec['trend'] = true
  end
  
  test 'bogus_trend_value_throws_error' do
    begin
      @series_spec['trend'] = 'bogus'
      series = Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('trend')
      return
    end
    fail('series creation should not succeed with bogus trend')
  end

  test 'default_trend_data_with_c3_enabled' do
    series = Series.new(@chart, @series_spec)
    assert_equal [10.0, 7.0, 4.0, 1.0, -2.0, -5.0, -8.0], series.trend_data
  end


  test 'trend_data_with_c3_enabled_shuld_not_skipp_any_data_point_when_trend_ignore_is_none' do
    @series_spec['trend-ignore'] = 'none'
    series = Series.new(@chart, @series_spec)
    assert_equal [9.8571, 8.1429, 6.4286, 4.7143, 3.0, 1.2857, -0.4286], series.trend_data
  end

  test 'trend_data_with_c3_enabled_should_skipp_trailing_zeroes_when_trend_ignore_is_zeroes_at_end' do
    @series_spec['trend-ignore'] = 'zeroes-at-end'
    series = Series.new(@chart, @series_spec)
    assert_equal [7.8, 8.1, 8.4, 8.7, 9.0, 9.3, 9.6], series.trend_data
  end

  test 'trend_data_with_c3_enabled_should_consider_specified_trend_scope' do
    @series_spec['trend-scope'] = 2
    series = Series.new(@chart, @series_spec)
    assert_equal [10.0, 7.0, 4.0, 1.0, -2.0, -5.0, -8.0], series.trend_data

    @series_spec['trend-ignore'] = 'zeroes-at-end'
    series = Series.new(@chart, @series_spec)
    assert_equal [-12.0, -4.0, 4.0, 12.0, 20.0, 28.0, 36.0], series.trend_data
  end

  test 'trend_data_with_c3_enabled_should_be_empty_when_there_is_only_one_data_point_to_calculate_trend_line' do
    @series_spec['trend-scope'] = 1
    series = Series.new(@chart, @series_spec)
    assert series.trend_data.blank?
  end

  test 'data_series_chart_parameter_definitions_do_not_include_stack_bar_chart_options' do
    assert_false Series.parameter_definitions_for_data_series_chart.collect(&:name).include?('hidden')
    assert_false Series.parameter_definitions_for_data_series_chart.collect(&:name).include?('combine')
  end
  
  test 'stack_bar_chart_parameter_definitions_include_stack_bar_chart_specific_options' do
    assert Series.parameter_definitions_for_stack_bar_chart.collect(&:name).include?('hidden')
    assert Series.parameter_definitions_for_stack_bar_chart.collect(&:name).include?('combine')
  end
  
  test 'trend_data_throws_error_when_invalid_trend_skip_option' do
    begin
      @series_spec['trend-ignore'] = 'bogus value'
      series = Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('trend-ignore')
      return
    end
    fail('series creation should not succeed with bogus trend skip')
  end
  
  test 'trend_data_throws_error_when_invalid_scope_option' do
    assert_trend_data_throws_error_when_specified_value_is_bad('bogus')
    assert_trend_data_throws_error_when_specified_value_is_bad(2.3)
    assert_trend_data_throws_error_when_specified_value_is_bad('2.3')
    assert_trend_data_throws_error_when_specified_value_is_bad(0.3)
    assert_trend_data_throws_error_when_specified_value_is_bad(0)
    assert_trend_data_throws_error_when_specified_value_is_bad(-1)
    assert_trend_data_throws_error_when_specified_value_is_bad(-1.4)
  end
  
  def assert_trend_data_throws_error_when_specified_value_is_bad(specified_value)
    begin
      @series_spec['trend-scope'] = specified_value
      series = Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('trend-scope')
      return
    end
    fail('series creation should not succeed with bogus trend scope')
  end
  
  test 'can_specify_trend_line_color' do
    @series_spec['trend-line-color'] = 'blue'
    series = Series.new(@chart, @series_spec)
    assert_equal Chart.color('blue') , series.trend_line_color
  end
  
  test 'trend_line_color_will_fall_back_on_main_color' do
    @series_spec['color'] = 'blue'
    @series_spec['trend-line-color'] = nil
    series = Series.new(@chart, @series_spec)
    assert_equal 'blue' , series.trend_line_color
  end
  
  test 'can_specify_solid_line_style' do
    @series_spec['trend-line-style'] = 'solid'
    series = Series.new(@chart, @series_spec)
    assert_equal 'solid', series.trend_line_style
  end
  
  test 'nonesense_line_style_is_illegal' do
    @series_spec['trend-line-style'] = 'bogus'
    begin
      series = Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('trend-line-style')
      return
    end
    fail ('should have blown up from bad trend-line-style')
  end
  
  test 'can_specify_trend_line_width' do
    @series_spec['trend-line-width'] = 5
    series = Series.new(@chart, @series_spec)
    assert_equal 5, series.trend_line_width
  end
  
  test 'can_specify_trend_line_width_with_string' do
    @series_spec['trend-line-width'] = '15'
    series = Series.new(@chart, @series_spec)
    assert_equal 15, series.trend_line_width
  end
  
  test 'nonsense_trend_line_width_uses_default' do
    @series_spec['trend-line-width'] = 'foo'
    series = Series.new(@chart, @series_spec)
    assert_equal 3, series.trend_line_width
  end
  
  test 'can_specify_line_width' do
    @series_spec['line-width'] = 5
    series = Series.new(@chart, @series_spec)
    assert_equal 5, series.line_width
  end
  
  test 'can_specify_line_width_with_string' do
    @series_spec['line-width'] = '15'
    series = Series.new(@chart, @series_spec)
    assert_equal 15, series.line_width
  end
  
  test 'nonsense_line_width_uses_default' do
    @series_spec['line-width'] = 'foo'
    series = Series.new(@chart, @series_spec)
    assert_equal 3, series.line_width
  end
  
  
  test 'can_specify_down_from' do
    def @chart.cumulative?
      true
    end
    @series_spec['data'] = %{SELECT 'Development Complete Iteration', SUM(Size)}
    @series_spec['down-from'] = %{SELECT SUM(Size) WHERE 'Entered Scope Iteration' IS NOT NULL}
    series = Series.new(@chart, @series_spec)
    assert_equal [33, 26, 22, 10, 10, 10, 10], series.values
  end
  
  test 'should_raise_readable_error_when_mql_does_not_have_column_name' do
    @series_spec['data'] = %{SELECT SUM(Size)}
    assert_raise RuntimeError do
      Series.new(@chart, @series_spec)
    end
    @series_spec['data'] = %{SELECT Size}
    assert_raise RuntimeError do
      Series.new(@chart, @series_spec)
    end
  end
  
  test 'cannot_specify_down_from_unless_chart_is_cumulative' do
    begin
      @series_spec['down-from'] = 'foo'
      series = Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('down-from')
      return
    end
    fail('should not have been able to specify down from on a non-cumulative chart')
  end
  
  test 'bogus_data_symbol_throws_error' do
    @series_spec['data-point-symbol'] = 'bogus'
    begin
      series = Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?("data-point-symbol")
      return
    end
    fail ('should have exploded from bad parameter')
  end

  test 'valid_data_symbol_should_not_throw_error' do
    [nil, '', 'none', 'circle', 'square', 'diamond'].each do |data_point_symbol|
    @series_spec['data-point-symbol'] = data_point_symbol
      assert_nothing_raised("Should allow #{data_point_symbol.inspect} as data-point-symbol") do
        Series.new(@chart, @series_spec)
      end
    end
  end

  test 'bogus_show_data_labels_value_throws_error' do
    @series_spec['data-labels'] = 'bogus'
    begin
      series = Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('data-labels')
      return
    end
    fail("should have blown up from bad data-labels")
  end
  
  # for bug #5280
  test 'should_throw_error_when_total_is_less_then_overlay_bottom' do
    @chart.series_overlay_bottom = [OpenStruct.new(:values => [10, 7, 4, 12, 0, 0, 1], :data_specification => 'overlay_bottom_specification')]
    @chart.series_overlay_top = []
    @series_spec['combine'] = 'total'
    series = Series.new(@chart, @series_spec)
    begin
      series.values
    rescue RuntimeError => e
      assert_include @series_spec['data'], e.message
      assert_include @chart.x_axis_values.last, e.message
      return
    end
    fail("should have blown up for total < overlay-bottom cases")
  end
    
  test 'will_delegate_to_chart_for_any_unset_params' do
    @chart.trend_scope = 5
    @chart.trend_ignore = 'none'
    @chart.trend_line_width = 8
    @chart.trend_line_style = 'solid'
    @chart.trend_line_color = 'green'
    @chart.trend = true
    @chart.chart_type = 'bar'
    @chart.data_point_symbol = 'square'
    
    @series_spec['trend'] = nil
    @series_spec['trend-scope'] = nil
    @series_spec['trend-ignore'] = nil
    @series_spec['trend-line-width'] = nil
    @series_spec['trend-line-style'] = nil
    @series_spec['trend-line-color'] = nil
    @series_spec['data-point-symbol'] = nil
    
    series = Series.new(@chart, @series_spec)
    
    assert_equal 8, series.trend_line_width
    assert_equal 'dash', series.trend_line_style
    assert series.trend
    assert_equal 'square', series.data_point_symbol
    assert_equal 'bar', series.layer_type
  end
  
  test 'should_load_data_from_specified_project' do
    @series_spec['project'] = "card_query_project"
    @series_spec['data'] = %{SELECT 'Release', count(*)}
    series = Series.new(@chart, @series_spec)
    assert_equal [1, 0, 0, 0, 0, 0, 0], series.values
  end
  
  test 'loading_date_data_when_date_format_for_chart_level_project_is_different_from_series_level_project' do
    @project.update_attribute(:date_format, '%m-%d-%Y')
    
    card_query_project = with_card_query_project do |project|
      project.update_attribute(:date_format, '%Y/%m/%d')
      create_card!(:name => 'card1', :date_created => '2009/1/1')
      create_card!(:name => 'card2', :date_created => '2009/1/2')
      create_card!(:name => 'card3', :date_created => '2009/1/2')
      project
    end
    @series_spec['project'] = "card_query_project"
    @series_spec['data'] = %{SELECT 'date_created', count(*)}
    @chart.x_axis_labels = DateXAxisLabels.new(card_query_project.find_property_definition('date_created'), :date_format => @project.date_format)
    @chart.x_axis_values = ['1-1-2009', '1-2-2009']
    series = Series.new(@chart, @series_spec)
    assert_equal [1, 2], series.values
  end
  
  test 'should_report_error_if_specified_project_not_found' do
    @series_spec['project'] = "project_that_doesnt_exist"
    @series_spec['data'] = %{SELECT 'Release', count(*)}
    
    begin
      Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('project_that_doesnt_exist')
      return
    end
    fail("should have blown up because project doesnt exist")
  end
    
  test 'should_report_error_if_specified_project_not_accessible_for_user' do
    card_query_project.with_active_project do |project|
      project.remove_member(User.current)
    end
    @series_spec['project'] = "card_query_project"
    @series_spec['data'] = %{SELECT 'Release', count(*)}
    
    begin
      Series.new(@chart, @series_spec)
    rescue RuntimeError => e
      assert e.message.include?('card_query_project')
      return
    end
    fail("should have blown up because cant access project")
  end

  test 'can_use_plvs' do
    chart = OpenStruct.new
    chart.cumulative = true
    chart.trend = true
    chart.data_point_symbol = true
    chart.line_style = 'dash'
    chart.line_width = 8
    chart.x_axis_labels = XAxisLabels.new(@project.find_property_definition('Development Complete Iteration'))
    def chart.cumulative?
      false
    end
    
    create_plv!(@project, :name => 'series_project',           :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => @project.identifier)
    create_plv!(@project, :name => 'series_color',             :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'blue')
    create_plv!(@project, :name => 'series_combine',           :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'fake combine value')
    create_plv!(@project, :name => 'series_data',              :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => %{SELECT 'Development Complete Iteration', SUM(Size)})
    create_plv!(@project, :name => 'series_data_labels',       :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'false')
    create_plv!(@project, :name => 'series_data_point_symbol', :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'square')
    create_plv!(@project, :name => 'series_label',             :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'my label')
    create_plv!(@project, :name => 'series_line_style',        :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'solid')
    create_plv!(@project, :name => 'series_line_width',        :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 4)
    create_plv!(@project, :name => 'series_trend',             :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'true')
    create_plv!(@project, :name => 'series_trend_ignore',      :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE)
    create_plv!(@project, :name => 'series_trend_line_color',  :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'green')
    create_plv!(@project, :name => 'series_trend_line_style',  :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'dash')
    create_plv!(@project, :name => 'series_trend_line_width',  :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 3)
    create_plv!(@project, :name => 'series_trend_scope',       :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => Series::TREND_SCOPE_ALL)
    create_plv!(@project, :name => 'series_type',              :data_type => ProjectVariable::STRING_DATA_TYPE,  :value => 'bar')

    series_spec = {}
    series_spec['project']           = '(series_project)'
    series_spec['color']             = '(series_color)'
    series_spec['combine']           = '(series_combine)'
    series_spec['data']              = '(series_data)'
    series_spec['data-labels']       = '(series_data_labels)'
    series_spec['data-point-symbol'] = '(series_data_point_symbol)'
    series_spec['label']             = '(series_label)'
    series_spec['line-style']        = '(series_line_style)'
    series_spec['line-width']        = '(series_line_width)'
    series_spec['trend']             = '(series_trend)'
    series_spec['trend-ignore']      = '(series_trend_ignore)'
    series_spec['trend-line-color']  = '(series_trend_line_color)'
    series_spec['trend-line-style']  = '(series_trend_line_style)'
    series_spec['trend-line-width']  = '(series_trend_line_width)'
    series_spec['trend-scope']       = '(series_trend_scope)'
    series_spec['type']              = '(series_type)'
    
    series = Series.new(chart, series_spec)
    
    assert_equal 'fake combine value', series.combine
    assert_equal 'square', series.data_point_symbol
    assert_equal 'my label', series.label
    assert_equal 'solid', series.line_style
    assert_equal 4, series.line_width
    assert_equal true, series.trend
    assert_equal 'dash', series.trend_line_style
    assert_equal 3, series.trend_line_width
    assert_equal 'bar', series.layer_type
  end

  test 'should_return_stripped_color_string_when_chart_is_stack_bar_chart' do
    chart = OpenStruct.new
    series = Series.new(chart, {'label' => 'Projects', 'data' => 'SELECT project, count(*)', 'color' => ' #0000FF ', 'combine' => 'overlay-bottom'})

    assert_equal('#0000FF', series.color)
  end

  test 'should_return_stripped_color_string_when_chart_is_ratio_bar_chart' do
    chart = OpenStruct.new
    series = Series.new(chart, {'label' => 'Projects', 'data' => 'SELECT project, count(*)', 'color' => ' #0000FF ', 'combine' => 'overlay-bottom'})

    assert_equal('#0000FF', series.color)
  end

  test 'should_return_transparent_for_hidden_series' do
    chart = OpenStruct.new

    series = Series.new(chart, {'label' => 'Projects', 'data' => 'SELECT project, count(*)', 'color' => '#0000FF', 'combine' => 'overlay-bottom', 'hidden' =>  true})

    assert_equal(Charts::C3Renderers::ColorPalette::Colors::TRANSPARENT, series.color)
  end

  test 'should_have_default_label' do
    chart = OpenStruct.new

    series = Series.new(chart, {'data' => 'SELECT project, count(*)', 'color' => '#0000FF', 'combine' => 'overlay-bottom'})

    assert_equal('Series', series.label)
  end
end
