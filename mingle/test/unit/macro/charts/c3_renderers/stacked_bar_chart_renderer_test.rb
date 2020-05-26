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
    class StackedBarChartRendererTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = StackedBarChartRenderer.new(300, 400)
      end

      test 'should_inherit_c3_series_renderer' do
        assert_equal SeriesChartRenderer, StackedBarChartRenderer.ancestors[1]
      end

      test 'mode_should_be_bar_by_default' do
        assert_equal(:bar, @renderer.instance_variable_get(:@mode))
      end

      test 'should_initialize_with_default_stack_bar_chart_options' do
        expected_chart_data = {'data' =>
                                   {'columns' =>[],
                                    'type' => 'bar',
                                    'order' =>nil,
                                    'types' =>{},
                                    'colors' =>{},
                                    'trends' => [],
                                    'groups' =>[[]],
                                    'regions' =>{}},
                               'legend' =>{'position' => 'top-right'},
                               'size' =>{'width' =>300, 'height' =>400},
                               'axis' =>{'x' =>{'type' => 'category'}, 'y' =>{'padding' => {'top' => 25}}},
                               'bar' =>{'width' =>{'ratio' =>0.85}},
                               'tooltip' =>{'grouped' =>false}}.with_indifferent_access

        assert_equal expected_chart_data, chart_options
      end

      test 'make_chart_should_add_all_the_series_labels_in_groups' do
        line_series_data = {'Line Series 1' => [[1, 2, 3, 4, 5], 'white', 'line'],
                            'Line Series 2' => [[2, 3, 5, 7, 11], 'red', 'line']}
        bar_series_data = {'Bar Series 1' => [[2, 4, 6, 8, 10], nil, nil],
                           'Bar Series 2' => [%w(a e i o u), '#ff0000', nil]}
        area_series_data = {'Area Series 1' => [%w(a b c d e), '#00ff00', 'area'],
                            'Area Series 2' => [%w(p q r s t), '#ff00ff', 'area']}

        add_line_series_and_assert_renderer(line_series_data)
        add_series(bar_series_data)
        @renderer.add_area_layer
        add_series(area_series_data)

        all_series_data = line_series_data.merge(bar_series_data).merge(area_series_data)

        assert_series_data all_series_data
        assert_equal all_series_data.keys, chart_options[:data][:groups][0]
      end
    end
  end
end
