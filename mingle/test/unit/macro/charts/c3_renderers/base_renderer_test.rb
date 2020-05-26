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
    class BaseRendererTest < ActiveSupport::TestCase
      include C3RendererTestHelpers

      def setup
        @renderer = BaseRenderer.new(300, 400)
      end

      test 'should_initialize_renderer_with_given_width_and_height' do
        renderer = BaseRenderer.new(300, 400)
        assert_equal '{"data":{"columns":[],"type":"","order":null},"legend":{},"size":{"width":300,"height":400}}', renderer.make_chart
      end

      test 'should_add_region_data' do
        @renderer.set_region_data({'2' =>{'LabelTwo' =>{'cards'=>[{'name'=> 'Blah', 'number'=> '5'}, {'name'=> 'Blah', 'number'=> '3'}], 'count'=>2}}, '1' =>{'LabelTwo' =>{'cards'=>[{'name'=> 'Blah', 'number'=> '1'}], 'count'=>1}}})

        expected = {'2' =>{'LabelTwo' =>{'cards'=>[{'name'=> 'Blah', 'number'=> '5'}, {'name'=> 'Blah', 'number'=> '3'}], 'count'=>2}}, '1' =>{'LabelTwo' =>{'cards'=>[{'name'=> 'Blah', 'number'=> '1'}], 'count'=>1}}}

        assert_equal(expected, chart_options[:region_data])

      end

      test 'should_add_region_mql_for_given_chart' do
        @renderer.set_region_mql({'conditions' =>
                                    {'1' =>
                                       {'LabelTwo' => 'Status = Closed AND old_type = Story AND Iteration = 1',
                                        'LabelOne' =>
                                          "Status = 'In Progress' AND old_type = Story AND Iteration = 1"}},
                                  'project_identifier' => 'stack_bar_chart_project'})

        expected_region_mql = {'conditions' =>
                                 {'1' =>
                                    {'LabelTwo' => 'Status = Closed AND old_type = Story AND Iteration = 1',
                                     'LabelOne' =>
                                       "Status = 'In Progress' AND old_type = Story AND Iteration = 1"}},
                               'project_identifier' => 'stack_bar_chart_project'}

        assert_equal(expected_region_mql, chart_options[:region_mql])
      end

      test 'set_title_should_add_title_for_given_chart' do
        title = 'chart title'
        @renderer.set_title(title)

        assert_equal(title, chart_options[:title][:text])
      end

      test 'set_legend_position_should_add_legend_position_for_given_chart' do
        position = 'bottom'
        @renderer.set_legend_position(position)

        assert_equal(position, chart_options[:legend][:position])
      end
    end
  end
end

