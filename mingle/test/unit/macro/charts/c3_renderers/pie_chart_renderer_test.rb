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
    class PieChartRendererTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = PieChartRenderer.new(300, 400)
      end

      test 'should_inherit_from_c3_renderer' do
        assert_equal BaseRenderer, PieChartRenderer.ancestors[1]
      end

      test 'should_have_default_chart_options' do
        expected_chart_options = {'data' => {'columns' => [], 'type' => 'pie', 'order' => nil},
                                  'size' => {'width' => 300, 'height' => 400}, 'legend' => {}}

        assert_equal expected_chart_options, chart_options
      end

      test 'add_text_should_add_title_text' do
        title = 'Chart title'
        @renderer.add_text(title)

        assert_equal title, chart_options[:title][:text]
      end

      test 'set_radius_should_set_approx_scaled_height_for_chart_when_radius_is_given_and_greater_than_0' do
        @renderer.set_radius(nil)

        assert_equal 400, chart_options[:size][:height]

        @renderer.set_radius(0)

        assert_equal 400, chart_options[:size][:height]

        radius = 300
        @renderer.set_radius(radius)

        assert_equal radius * 2.1, chart_options[:size][:height]
      end

      test 'set_data_should_set_data_columns' do
        data = [2, 5, 9, 67, 3, 6]
        @renderer.set_data(data)

        assert_equal data, chart_options[:data][:columns]
      end

      test 'set_title_should_set_title_text' do
        title = 'Chart title'
        @renderer.set_title(title)

        assert_equal title, chart_options[:title][:text]
      end

      test 'set_label_type_should_set_the_label_type_for_chart_data' do
        label_type = 'percentage'
        @renderer.set_label_type(label_type)

        assert_equal label_type, chart_options[:label_type]
      end

      test 'set_legend_position_should_set_the_legend_position' do
        legend_position = 'right'
        @renderer.set_legend_position(legend_position)

        assert_equal legend_position, chart_options[:legend][:position]
      end
    end
  end
end
