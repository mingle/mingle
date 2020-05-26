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
    class CumulativeFlowGraphRendererTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = CumulativeFlowGraphRenderer.new(400, 500)
      end

      test 'should_inherit_stacked_bar_chart_renderer' do
        assert_equal StackedBarChartRenderer, CumulativeFlowGraphRenderer.ancestors[1]
      end

      test 'mode_should_be_area_by_default' do
        assert_equal(:area, @renderer.instance_variable_get(:@mode))
      end

      test 'dash_line_color_should_return_the_color_and_style_hash' do
        assert_equal({color: 'white', style: :dashed}, @renderer.dash_line_color('white'))
      end

      test 'dash_line_color_should_convert_numeric_color_to_hex_value' do
        assert_equal({color: '#01e240', style: :dashed}, @renderer.dash_line_color(123456))
      end

      test 'set_data_symbol_should_set_symbol_type_for_data_points_for_series' do
        add_series({'Series 1' => [[2, 4, 6, 8, 10], 'white', nil]})
        add_series({'Series 2' => [%w(a e i o u), '#ff0000', nil]})
        @renderer.set_data_symbol('diamond')
        add_series({'Series 3' => [%w(b c d f g), '#ff00ff', nil]})

        data_point_symbols = chart_options[:point][:symbols]
        assert_nil data_point_symbols['Series 1']
        assert_equal('diamond', data_point_symbols['Series 2'])
        assert_nil data_point_symbols['Series 3']
      end

      test 'set_data_label_format_should_add_series_label_in_data_labels' do
        add_series({'Series 1' => [[2, 4, 6, 8, 10], 'white', nil]})
        add_series({'Series 2' => [%w(a e i o u), '#ff0000', nil]})
        @renderer.set_data_label_format
        add_series({'Series 3' => [%w(b c d f g), '#ff00ff', nil]})
        @renderer.set_data_label_format

        assert_equal({'Series 2' => true, 'Series 3' => true}, chart_options[:data][:labels][:format])
        assert_nil chart_options[:data][:labels][:format]['Series 1']
      end
    end
  end
end

