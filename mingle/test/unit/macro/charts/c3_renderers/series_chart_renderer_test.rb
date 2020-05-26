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
    class SeriesChartRendererTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = SeriesChartRenderer.new(300, 400)
      end

      test 'should_inherit_from_xy_chart' do
        assert_equal XYChartRenderer, SeriesChartRenderer.ancestors[1]
      end

      test 'should_set_default_series_options' do
        expected_default_options = {'data' =>
                                        {'columns' => [],
                                         'type' => '',
                                         'order' => nil,
                                         'types' => {},
                                         'trends' => [],
                                         'colors' => {},
                                         'groups' => [[]],
                                         'regions' => {}},
                                    'size' => {'width' => 300, 'height' => 400},
                                    'legend' => {},
                                    'axis' => {'x' => {'type' => 'category'}, 'y' => {'padding' => {'top' => 25}}}}

        assert_equal expected_default_options, chart_options
      end

      test 'add_line_should_add_data_for_line_with_label_and_color_and_return_the_renderer' do
        line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5, 6, 7], 'white', 'line'],
                            'Line Series 2' => [[2, 3, 5, 7, 11, 13, 17], 'red', 'line']}
        add_line_series_and_assert_renderer(line_series_data)

        assert_series_data line_series_data
      end

      test 'add_line_should_not_add_line_for_label_with_empty_data' do
        actual_line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5, 6, 7], 'white', 'line'],
                            'Line Series 2' => [[2, 3, 5, 7, 11, 13, 17], 'red', 'line'],
                            'Line Series 3' => [[],'yellow','line']}
        expected_line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5, 6, 7], 'white', 'line'],
                                     'Line Series 2' => [[2, 3, 5, 7, 11, 13, 17], 'red', 'line']}
        add_line_series_and_assert_renderer(actual_line_series_data)

        assert_series_data expected_line_series_data
      end

      test 'add_trend_line_should_add_line_with_label_and_color_and_return_the_renderer' do
        line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5, 6, 7], 'white', 'line'],
                            'Line Series 2' => [[2, 3, 5, 7, 11, 13, 17], 'red', 'line']}
        add_trend_line_series_and_assert_renderer(line_series_data)

        assert_series_data line_series_data
      end

      test 'add_trend_line_should_add_series_label_to_trends' do
        line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5, 6, 7], 'white', 'line']}
        add_trend_line_series_and_assert_renderer(line_series_data)

        assert_equal ['Line Series 1'], chart_options[:data][:trends]
      end

      test 'add_line_should_add_data_for_dashed_line_with_label_and_color_and_return_the_renderer' do
        line_series_data = {'dashed line' => [[1, 2, 3, 4, 5, 6, 7], {color: 'white', style: :dashed}, 'line'],
                            'Line Series 2' => [[2, 3, 5, 7, 11, 13, 17], 'red', 'line']}
        add_line_series_and_assert_renderer(line_series_data)

        assert_series_data line_series_data
      end

      test 'add_line_should_handle_numeric_colors' do
        line_series_data = {'Line Series' => [[1, 2, 3, 4, 5, 6, 7], 16777215, 'line']}
        add_line_series_and_assert_renderer(line_series_data)

        assert_equal '#ffffff', chart_options[:data][:colors]['Line Series']
      end

      test 'add_data_set_should_add_data_for_bar_with_label_and_color_and_not_add_to_types' do
        bar_series_data = {'Bar Series 1' => [[1, 2, 3, 4, 5, 6, 7], 'white', 'bar'],
                           'Bar Series 2' => [[2, 3, 5, 7, 11, 13, 17], '#ff00ff', 'bar']}
        @renderer.add_bars
        add_series(bar_series_data)

        assert_series_data bar_series_data
      end

      test 'add_data_set_should_handle_numeric_color_values' do
        bar_series_data = {'Bar Series' => [[1, 2, 3, 4, 5, 6, 7], 16777215, 'bar']}
        area_series_data = {'Area Series' => [[2, 3, 5, 7, 11, 13, 17], 16711680, 'area']}

        @renderer.add_bars
        add_series(bar_series_data)

        @renderer.add_area_layer
        add_series(area_series_data)

        colors_data = chart_options[:data][:colors]

        assert_equal('#ffffff', colors_data['Bar Series'])
        assert_equal('#ff0000', colors_data['Area Series'])
      end

      test 'add_data_set_should_add_data_for_area_with_label_and_color' do
        data = [1, 2, 3, 4, 5, 6, 7]
        name = 'Area Series'
        color = '#0000ff'
        @renderer.add_area_layer
        @renderer.add_data_set(data.clone, color, name)

        series_data = chart_options[:data]
        assert_equal data.unshift(name), series_data[:columns][0]
        assert_equal 'area', series_data[:types][name]
        assert_equal color, series_data[:colors][name]
        assert_equal [], series_data[:groups][0]
      end

      test 'add_data_set_should_not_add_color_when_not_specified' do
        data = [1, 2, 3, 4, 5, 6, 7]
        name = 'Bar Series'
        color = ''
        @renderer.add_data_set(data.clone, color, name)

        assert_equal(nil, chart_options[:data][:colors][name])
      end

      test 'make_chart_should_add_groups_to_data' do
        line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5], 'white', 'line'],
                            'Line Series 2' => [[2, 3, 5, 7, 11], 'red', 'line']}
        bar_series_data = {'Bar Series 1' => [[2, 4, 6, 8, 10], nil, 'bar'],
                           'Bar Series 2' => [%w(a e i o u), '#ff0000', 'bar']}
        area_series_data = {'Area Series 1' => [%w(a b c d e), '#00ff00', 'area'],
                            'Area Series 2' => [%w(p q r s t), '#ff00ff', 'area']}

        add_line_series_and_assert_renderer(line_series_data)
        @renderer.add_bars
        add_series(bar_series_data)
        @renderer.add_area_layer
        add_series(area_series_data)

        all_series_data = line_series_data.merge(bar_series_data).merge(area_series_data)

        assert_series_data all_series_data
        assert_equal [], chart_options[:data][:groups][0]
      end

      test 'set_x_axis_label_step_should_set_the_culling_when_step_is_greater_than_1' do
        line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5], 'white', 'line'],
                            'Line Series 2' => [[2, 3, 5, 7, 11], 'red', 'line']}
        add_line_series_and_assert_renderer(line_series_data)
        @renderer.set_x_axis_label_step(1)

        assert_nil chart_options[:axis][:x][:tick]

        @renderer.set_x_axis_label_step(3)

        assert_equal(2, chart_options[:axis][:x][:tick][:culling][:max])

        @renderer.set_x_axis_label_step(2)

        assert_equal(3, chart_options[:axis][:x][:tick][:culling][:max])

        @renderer.set_x_axis_label_step(5)

        assert_equal(1, chart_options[:axis][:x][:tick][:culling][:max])
      end

      test 'should_define_compatibility_methods' do
        [:add_legend, :set_line_width, :set_bar_gap].each do |method|
          assert_nothing_raised do
            assert_same @renderer, @renderer.send(method, *random_args)
          end
        end
      end

      test 'should_hide_legend_for_hidden_line_series' do
        @renderer.add_line([1, 2, 3, 4, 5], ColorPalette::Colors::TRANSPARENT, 'Series 1')

        assert_equal ['Series 1'], chart_options[:legend][:hide]
      end

      test 'should_hide_legend_for_hidden_bar_series' do
        @renderer.add_bars
        @renderer.add_data_set([1, 2, 3, 4, 5], ColorPalette::Colors::TRANSPARENT, 'Series 1')

        assert_equal ['Series 1'], chart_options[:legend][:hide]
      end

      test 'should_hide_legend_for_hidden_area_series' do
        @renderer.add_area_layer
        @renderer.add_data_set([1, 2, 3, 4, 5], ColorPalette::Colors::TRANSPARENT, 'Series 1')

        assert_equal ['Series 1'], chart_options[:legend][:hide]
      end
    end
  end
end
