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
    class XYChartTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = XYChartRenderer.new(300, 400)
      end

      test 'should_inherit_from_c3_renderer' do
        assert_equal BaseRenderer, XYChartRenderer.ancestors[1]
      end

      test 'should_add_default_axes_options' do
        axis_options = chart_options[:axis]

        assert_equal({'type' => 'category'}, axis_options[:x])
        assert_equal({'padding' => {'top' => 25}}, axis_options[:y])
      end

      test 'add_titles_to_axes_should_add_titles_for_axes' do
        x_axis_title = 'xAxisTitle'
        y_axis_title = 'yAxisTitle'

        @renderer.add_titles_to_axes(x_axis_title, y_axis_title)

        axis_options = chart_options[:axis]
        assert_equal({'text' => x_axis_title, 'position' => 'outer-center'}, axis_options[:x][:label])
        assert_equal({'text' => y_axis_title, 'position' => 'outer-middle'}, axis_options[:y][:label])
      end

      test 'set_x_axis_labels_should_add_labels_to_x_axis_along_with_the_font_angle' do
        labels = %w(label1 label2 label3)

        @renderer.set_x_axis_labels(labels, nil, 35)

        x_axis_options = chart_options[:axis][:x]
        assert_equal(labels, x_axis_options[:categories])
        assert_equal({'rotate' => 35, 'multiline' => false, 'centered' => true}, x_axis_options[:tick])
      end

      test 'set_x_axis_label_step_should_set_the_label_step' do
        step = 5
        @renderer.set_x_axis_label_step(step)

        assert_equal step, @renderer.instance_variable_get(:@step)
      end

      test 'should_define_compatibility_methods' do
        [:set_axes_colors, :set_border_color, :set_3d, :transparent_color].each do |method|
          assert_nothing_raised do
            assert_same @renderer, @renderer.send(method, *random_args)
          end
        end
      end

      test 'set_legend_position_should_use_legend_position_translations' do
        @renderer.set_legend_position('right')

        assert_equal 'top-right', chart_options[:legend][:position]
      end

      test 'should_show_only_y_grid_lines' do
        @renderer.show_guide_lines

        assert_false chart_options[:grid][:x][:show]
        assert chart_options[:grid][:y][:show]
      end
    end
  end
end
