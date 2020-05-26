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
    class RatioBarChartRendererTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = RatioBarChartRenderer.new(300, 400)
      end

      test 'should_inherit_from_xy_chart' do
        assert_equal XYChartRenderer, RatioBarChartRenderer.ancestors[1]
      end

      test 'should_initialize_with_default_ratio_bar_chart_options' do
        expected_chart_data = {
            'data' => {'columns' => [], 'type' => 'bar', 'order' => nil},
            'size' => {'width' => 300, 'height' => 400},
            'axis' => {'x' => {'type' => 'category'},
                       'y' => {'min' => 0, 'max' => 100, 'tick' => {'format' => ''},
                               'padding' => {'top' => 5, 'bottom' => 0}}},
            'tooltip' => {'grouped' => false},
            'legend' => {'hide' => true}
        }

        assert_equal expected_chart_data, chart_options
      end

      test 'should_set_title_for_chart' do
        @renderer.set_title('My Title')

        assert_equal 'My Title', chart_options['title']['text']
      end

      test 'should_set_labels_with_font_angle_for_chart' do
        labels = %w(a b)
        font_angle = 45
        @renderer.set_x_axis_labels(labels, nil, font_angle)

        assert_equal font_angle, chart_options[:axis][:x][:tick][:rotate]
        assert_equal labels, chart_options[:axis][:x][:categories]
      end

      test 'should_add_bars_with_data_and_color' do
        @renderer.add_bars([], '#ff000')
        expected_data = {'columns'=>[['data']], 'type'=>'bar', 'order'=>nil, 'colors'=>{'data'=>'#ff000'}}

        assert_equal(expected_data, chart_options[:data])
      end
    end
  end
end
