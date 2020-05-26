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

class OrderedYAMLWriterTest < ActiveSupport::TestCase
  
  def test_can_write_out_yaml_in_the_order_of_provided_parameter_definitions
    name_pd = parameter_definition('first_name', :required => true)
    abc_pd = parameter_definition('abc', :required => true)
    
    expected = <<-EXPECTD
  first-name: jane
  abc: locomoco
    EXPECTD
    assert_generated_content(expected, [name_pd, abc_pd], { 'abc' => 'locomoco', 'first-name' => 'jane'})
    
    expected = <<-EXPECTD
  abc: locomoco
  first-name: jane
    EXPECTD
    assert_generated_content(expected, [name_pd, abc_pd].reverse, { 'abc' => 'locomoco', 'first-name' => 'jane'})
  end
  
  def test_required_parameters_always_get_written_out
    param_defs = [parameter_definition('name', :required => true), parameter_definition('abc', :required => true)]
    expected = <<-EXPECTD
  name: jane
  abc: 
    EXPECTD
    assert_generated_content(expected, param_defs, { 'name' => 'jane' })
  end
  
  def test_only_parameters_with_actual_specified_values_and_not_required_get_written_out
    param_defs = [parameter_definition('name', :required => true), parameter_definition('abc', :required => false)]
    expected = <<-EXPECTD
  name: jane
    EXPECTD
    assert_generated_content(expected, param_defs, { 'name' => 'jane' })
  end

  def test_parameter_values_are_escaped_for_yaml_syntax
    param_defs = [parameter_definition('name', :required => true), parameter_definition('abc', :required => false)]
    expected = <<-EXPECTD
  name: "#jane"
    EXPECTD
    assert_generated_content(expected, param_defs, { 'name' => '#jane' })
  end

  def test_multi_level_hashes_get_written_out_as_correctly_indented_yaml
    param_defs = [parameter_definition('series', :required => true, :list_of => multi_level_param_def)]
    expected = <<-EXPECTD
  series:
  - name: jane
    job: fisherman
  - name: tarzan
    job: fisherman
    EXPECTD
    assert_generated_content(expected, param_defs, {'series' => [{'name' => 'jane'}, {'name' => 'tarzan'}]})
  end

  def test_should_handle_values_with_single_quot
    param_defs = [parameter_definition('conditions', :required => true),parameter_definition('color')]
    expected = <<-EXPECTD
  conditions: \"Type\" = \"St'ory\" AND TAGGED WITH \"blocke'd\"
  color: \"#FFA4D3\"
      EXPECTD
    assert_generated_content(expected, param_defs, { 'conditions' => "\"Type\" = \"St'ory\" AND TAGGED WITH \"blocke'd\"" ,'color' => '#FFA4D3'})
  end

  def test_should_not_add_new_line_value_is_long
    param_defs = [parameter_definition('conditions', :required => true)]
    long_string = '"TYPE" IS "STORY" AND "STATUS" IN ("A", "B", "C") blah "Estimate Category" "Blue estimated"'
    expected = <<-EXPECTD
  conditions: #{long_string}
    EXPECTD
    assert_generated_content(expected, param_defs, { 'conditions' => long_string})
  end

  def test_should_not_replace_ending_quot_if_no_starting_quot
    param_defs = [parameter_definition('data', :required => true),parameter_definition('color')]
    expected = <<-EXPECTD
  data: SELECT status, count(*) where type='Card'
  color: \"#FFA4D3\"
    EXPECTD
    assert_generated_content(expected, param_defs, { 'data' => "SELECT status, count(*) where type='Card'" ,'color' => '#FFA4D3'})
  end

  def test_multi_level_hashes_get_written_out_as_correctly_indented_yaml
    param_defs = [parameter_definition('series', :required => false, :list_of => multi_level_param_def)]
    assert_generated_content("", param_defs, { 'series' => [] })
  end

  def test_parameters_without_specified_values_do_not_generate_content
    param_defs = [parameter_definition('name', :required => false, :example => 'timmy'), parameter_definition('abc', :required => false)]
    expected = ""
    assert_generated_content(expected, param_defs, {})
  end

  def test_list_parameters_without_specified_values_do_not_generate_content
    param_defs = [parameter_definition('series', :required => true, :list_of => multi_level_param_def)]
    expected = "  series:\n"
    assert_generated_content(expected, param_defs, { 'series' => [{}, {}] })
    assert_generated_content(expected, param_defs, { 'series' => [{'name' => ''}, {'name' => nil}] })
  end
  
  protected
  
  def multi_level_param_def
    parameterized_thing = Class.new
    parameterized_thing.send :include, Macro::ParameterSupport
    parameterized_thing.instance_eval do
      parameter 'name', :required => false, :example => 'mike'
      parameter 'job', :example => 'fisherman'
    end
    parameterized_thing
  end
  
  def assert_generated_content(expected, param_defs, params)
    assert_equal expected, OrderedYAMLWriter.new(param_defs).write(params)
  end
  
  def parameter_definition(name, options = {})
    Macro::ParameterDefinition.new(name, options)
  end
end
