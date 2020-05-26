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

class MacroBuilderTest < ActiveSupport::TestCase
  def test_build_default_macro
    macro = <<-MACRO
{{
  name
    p1: parameter_value
}}
MACRO
    
    builder = Macro::Builder.parse(macro)
    assert_equal macro, builder.build
  end

  def test_should_output_params_with_same_order_inputed
    macro = <<-MACRO
{{
  name
    p1: v1
    p3: v3
    p0: v0
    p2: v2
}}
MACRO

    builder = Macro::Builder.parse(macro)
    assert_equal macro, builder.build
  end

  def test_build_macro_with_new_parameter_value
    macro = <<-MACRO
{{
name
  p1: v1
  p3: v3
  p0: v0
}}
MACRO

    builder = Macro::Builder.parse(macro)
    result = builder.build(:p3 => 'new v3')
    assert_equal <<-MACRO, result
{{
  name
    p1: v1
    p3: new v3
    p0: v0
}}
MACRO
  end

  def test_build_macro_with_series
    macro = <<-MACRO
{{
  name
    p1: p1 value
    p2: p2 value
    series:
    - label: mingle
      color: red
    - label: go
      color: green
}}
MACRO

    builder = Macro::Builder.parse(macro)
    assert_equal macro, builder.build
  end

  def test_always_put_series_as_last_parameter_in_output
    macro = <<-MACRO
{{
  name
    p1: p1 value
    series:
    - label: mingle
      color: red
    - label: go
      color: green
    p2: p2 value
}}
MACRO

    builder = Macro::Builder.parse(macro)
    expected = <<-MACRO
{{
  name
    p1: p1 value
    p2: p2 value
    series:
    - label: mingle
      color: red
    - label: go
      color: green
}}
MACRO
    assert_equal expected, builder.build
  end

  def test_build_macro_with_new_series
    macro = <<-MACRO
{{
  name
    p1: p1 value
    p2: p2 value
    series:
    - label: mingle
      color: red
    - label: go
      color: green
}}
MACRO

    builder = Macro::Builder.parse(macro)

    expected = <<-MACRO
{{
  name
    p1: p1 value
    p2: p2 value
    series:
    - label: time
      color: white
    - label: machine
      color: black
}}
MACRO
    new_params = Macro::Builder.parse_parameters(<<-MACRO)
series:
- label: time
  color: white
- label: machine
  color: black
MACRO
    assert_equal expected, builder.build(new_params)
  end

  def test_merge_parameters
    macro = <<-MACRO
{{
  name
    p1: p1 value
    p2: p2 value
    series:
    - label: mingle
      color: red
    - label: go
      color: green
}}
MACRO

    builder = Macro::Builder.parse(macro)
    new_params = Macro::Builder.parse_parameters("p1: new value")
    builder = builder.merge(new_params)

    assert_equal 'new value', builder.parameters.params['p1']
  end

  def test_merge_parameters_should_not_change_default_params_order
    macro = <<-MACRO
{{
  name
    p1: p1 value
    p2: p2 value
    series:
    - label: mingle
      color: red
    - label: go
      color: green
}}
MACRO

    builder = Macro::Builder.parse(macro)
    new_params = Macro::Builder.parse_parameters("p1: new value\np3: p3 value")
    builder = builder.merge(new_params)

    assert_equal ['p1', 'p2', 'p3', 'series'], builder.parameters.order
  end

  def test_should_convert_underscore_in_param_name
    macro = <<-MACRO
{{
  name
    p-1: p1 value
}}
MACRO

    builder = Macro::Builder.parse(macro)

    expected = <<-MACRO
{{
  name
    p-1: new value
}}
MACRO
    assert_equal expected, builder.build(:p_1 => 'new value')
  end
end
