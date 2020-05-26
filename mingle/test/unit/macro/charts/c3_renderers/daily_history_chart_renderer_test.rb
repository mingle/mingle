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

require File.expand_path(File.dirname(__FILE__) + '/../../../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/c3_renderer_test_helpers')

module Charts
  module C3Renderers
    class DailyHistoryChartRendererTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = DailyHistoryChartRenderer.new(400, 500)
      end

      test 'should_inherit_data_series_chart_renderer' do
        assert_equal DataSeriesChartRenderer, DailyHistoryChartRenderer.ancestors[1]
      end

      test 'should_set_message' do
        expected_message = 'chart not ready'
        @renderer.set_message(expected_message)

        assert_equal expected_message, chart_options[:message]
      end

      test 'should_set_zoom' do
        @renderer.set_zoom(true)
        expected = {'enabled' => true}
        assert_equal expected, chart_options[:zoom]
      end

      test 'should_set_x_values' do
        xs_label = '_$$dates'
        x_values = (Date.parse('01-01-2018')..Date.parse('20-01-2018')).to_a.map(&:to_epoch_milliseconds)
        @renderer.set_x_values(x_values, xs_label, 'series-label')
        expected_date_in_epoch = [xs_label] + x_values
        expected_xs = {'series-label' => xs_label}

        assert_equal expected_date_in_epoch, chart_options[:data][:columns][0]
        assert_equal expected_xs, chart_options[:data][:xs]
      end

      test 'should_set_x_values_multiple_series' do
        xs_label = '_$$dates'
        x_values = (Date.parse('01-01-2018')..Date.parse('20-01-2018')).to_a.map(&:to_epoch_milliseconds)

        @renderer.set_x_values(x_values, xs_label, 'series1-label', 'series2-label')
        expected_date_in_epoch = [xs_label] + x_values
        expected_xs = {'series1-label' => xs_label, 'series2-label' => xs_label}

        assert_equal expected_date_in_epoch, chart_options[:data][:columns][0]
        assert_equal expected_xs, chart_options[:data][:xs]
      end

      test 'should_set_legend_style_to_given_type' do
        @renderer.set_legend_style('Scope' ,'dashed')
        expected_regions = {'style' => 'dashed'}

        assert_equal expected_regions ,chart_options[:legends_style]['Scope']
      end

      test  'should_set_x_axis_labels' do

        @renderer.set_x_axis_labels(nil,nil,45,{type: 'timeseries',format:'%d %b %Y'})
        expected_tick_options  = {'rotate' => 45, 'multiline' =>  false, 'centered' => true, 'format' => '%d %b %Y'}
        assert_equal 'timeseries', chart_options[:axis][:x][:type]
        assert_equal expected_tick_options, chart_options[:axis][:x][:tick]
      end

      test  'should_set_forecast_guide_lines' do
        @renderer.set_forecasts_guide_line(100, 123456)
        expected_forecast_guide_lines = [{'value' => 100, 'color' => '#01e240', 'class' => 'dashed-guideline'}]
        actual_forecast_guide_lines = chart_options[:grid][:y][:lines]

        assert_equal expected_forecast_guide_lines, actual_forecast_guide_lines
      end

      test  'should_set_multiple_forecast_guide_lines' do
        @renderer.set_forecasts_guide_line(100, 123456)
        @renderer.set_forecasts_guide_line(200, 'red')
        expected_forecast_guide_lines = [{'value' => 100, 'color' => '#01e240', 'class' => 'dashed-guideline'},
                                         {'value' => 200, 'color' => 'red', 'class' => 'dashed-guideline'}]
        actual_forecast_guide_lines = chart_options[:grid][:y][:lines]

        assert_equal expected_forecast_guide_lines, actual_forecast_guide_lines
      end

      test  'should_set_fix_date_guide_lines' do
        forecast1_guide_line_date = Date.parse('10 JAN 2018').to_epoch_milliseconds
        @renderer.set_fix_date_guide_line(forecast1_guide_line_date, '10 JAN 2018')
        expected_forecast_guide_lines = [{'value' => forecast1_guide_line_date, 'text'=> '10 JAN 2018', 'class' => 'dashed-guideline', 'position' => 'start'}]
        actual_forecast_guide_lines = chart_options[:grid][:x][:lines]

        assert_equal expected_forecast_guide_lines, actual_forecast_guide_lines
      end

      test 'should_set_forecast_data_labels' do
        forecast_series_labels = {'Series 1' => 'label one', 'Series 2' => 'label two'}
        @renderer.set_data_labels('Series 1', 'label one')
        @renderer.set_data_labels('Series 2', 'label two')
        assert_equal forecast_series_labels,  chart_options[:custom_series_labels]
      end

      test 'should_hide_legend_for_line' do
        @renderer.add_line([1, 2, 3, 4, 5], 'red', 'Series 1', true)
        assert_equal ['Series 1'], chart_options[:legend][:hide]
      end

      test 'should_set_data_class' do
        @renderer.set_data_class('series 1', 'custom-class-name')
        expected = {'series 1' => 'custom-class-name'}
        assert_equal expected, chart_options[:data][:classes]
      end

      test 'should_set_positions_of_data_label_to_enable' do
        forecast_series_labels = {'positions' => [2]}
        @renderer.enable_data_labels_on_selected_positions('Series 1', 2)
        assert_equal forecast_series_labels,  chart_options[:custom_series_labels]['Series 1']
      end

      test 'should_set_positions_of_multiple_data_labels_to_enable' do
        forecast_series_labels = {'positions' => [2,3,4]}
        @renderer.enable_data_labels_on_selected_positions('Series 1', 2,3,4)
        assert_equal forecast_series_labels,  chart_options[:custom_series_labels]['Series 1']
      end

      test 'should_hide_tooltip_for_given_series' do
        @renderer.hide_tooltip('series')

        assert_equal ['series'],  chart_options[:series_without_tooltip]
      end

      test 'should_hide_tooltip_for_multiple_series' do
        @renderer.hide_tooltip('series-1','series-2','series-3')

        assert_equal ['series-1','series-2','series-3'],  chart_options[:series_without_tooltip]
      end

      test 'should_add_legend_with_transparent_series' do
        label = 'hidden-series-with-legend'
        @renderer.add_legend_key(label, 1234, 'x_label')

        assert_equal [[label, 0], ['x_label', 1234]], chart_options[:data][:columns]

        assert_equal 'transparent', chart_options[:data][:colors][label]
        assert_equal 'line', chart_options[:data][:types][label]
        assert_equal 'hidden-series-with-legend', chart_options[:data][:classes][label]

      end

      test 'should_use_x_for_all_column_to_calculate_max_culling_when_forecast_not_set' do
        @renderer.set_x_values([1,2,3,4,5], "_$xForAll", 'a','b')
        @renderer.set_x_axis_label_step(2)
        assert_equal 3, chart_options[:axis][:x][:tick][:culling][:max]
      end

      test 'should_use_x_for_all_and_hidden_series_columns_to_calculate_max_culling_when_forecast_set' do
        @renderer.set_x_values([1,2,3,4,7,10], "_$xForAll", 'a','b')
        @renderer.set_x_values([7,10,13,15], "_$xFor #{Time.now.milliseconds.to_s}", 'a','b')
        @renderer.set_x_axis_label_step(3)
        assert_equal 3, chart_options[:axis][:x][:tick][:culling][:max]
      end
    end
  end
end

