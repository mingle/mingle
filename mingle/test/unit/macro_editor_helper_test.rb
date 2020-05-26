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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class MacroEditorHelperTest < ActiveSupport::TestCase
  include MacroEditorHelper

  test 'section_class_should_add_section_collapse_when_expanded' do
    section = Macro::ParamDefinitionSection.new(collapsed: false)

    assert_equal(  'section-toggle section-collapse',section_class(section))
  end

  test 'section_class_should_add_section_expand_when_collapsed' do
    section = Macro::ParamDefinitionSection.new(collapsed: true)

    assert_equal(  'section-toggle section-expand',section_class(section))
  end

  test 'section_class_should_add_disabled_when_section_is_disabled' do
    section = Macro::ParamDefinitionSection.new(disabled: true)

    assert_equal(  'section-toggle section-collapse disabled',section_class(section))
  end

  test 'render_for_description_should_return_true_when_chart_is_pie_chart' do
    assert render_placeholder_for_description?('pie-chart')
    assert_false render_placeholder_for_description?('other-than-pie-chart')
  end

  test 'render_for_description_should_return_true_when_chart_is_daily_history_chart' do
    assert render_placeholder_for_description?('daily-history-chart')
  end

  test 'render_for_description_should_return_true_when_chart_is_stack_bar_chart' do
    assert render_placeholder_for_description?('stack-bar-chart')
    assert_false render_placeholder_for_description?('other-than-stack-bar-chart')
  end

  test 'render_for_description_should_return_true_when_chart_is_stacked_bar_chart' do
    assert render_placeholder_for_description?('stacked-bar-chart')
    assert_false render_placeholder_for_description?('other-than-stacked-bar-chart')
  end

  test 'render_for_description_should_return_true_for_cumulative_flow_graph' do
    assert render_placeholder_for_description?('cumulative-flow-graph')
  end

end
