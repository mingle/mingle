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

class ParamDefinitionSectionTest < ActiveSupport::TestCase

  def test_all_param_defs_should_return_all_nested_param_defs
    simple_param_def = Macro::ParameterDefinition.new(:project, values: %w(first_project), initial_value: 'first_project', required: true, type: SimpleParameterInput.new('single_select_parameter_input'))
    pair_param_def = Macro::PairParameterDefinition.new(:param_defs => [Macro::ParameterDefinition.new(:aggregate_type, values: %w(Count Sum Average), required: true, type: SimpleParameterInput.new('single_select_parameter_input')),
                                                       Macro::ParameterDefinition.new(:aggregate_property, required: true, type: SimpleParameterInput.new('single_select_parameter_input'))])
    group_param_def = Macro::GroupedParameterDefinition.new(:param_defs => [
        Macro::ParameterDefinition.new(:chart_size, values: %w(small medium large), initial_value: 'medium', type: SimpleParameterInput.new('single_select_parameter_input')),
        Macro::ParameterDefinition.new(:label_type, values: %w(percentage whole\ number), initial_value: 'percentage', type: SimpleParameterInput.new('single_select_parameter_input')),
        Macro::ParameterDefinition.new(:legend_position, values: %w(right bottom), initial_value: 'right', type: SimpleParameterInput.new('single_select_parameter_input')),
    ])
    param_defs = [simple_param_def, pair_param_def, group_param_def]


    param_def_section = Macro::ParamDefinitionSection.new(:param_defs => param_defs)
    expected_param_defs = [simple_param_def, pair_param_def.param_defs, group_param_def.param_defs].flatten
    assert_equal(expected_param_defs, param_def_section.all_param_defs)
  end
end
