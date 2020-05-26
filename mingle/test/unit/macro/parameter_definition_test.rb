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

class ParameterDefinitionTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @project = first_project
    @project.activate
    @card = @project.cards.first
  end

  def teardown
    logout_as_nil
  end

  test 'required_returns_true' do
    assert_equal true, Macro::ParameterDefinition.new('name', :required => true).missing_required?({})
  end

  test 'required_returns_false' do
    assert_equal false, parameter_definition('name').missing_required?({})
  end

  test 'missing_required_returns_false_if_definition_is_not_required' do
    assert_equal false, parameter_definition('name').missing_required?({})
  end

  test 'missing_required_returns_false_if_definition_requires_it_and_provided' do
    assert_equal false, parameter_definition('name', :required => true).missing_required?({ 'name' => 'here' })
  end

  test 'missing_required_returns_true_if_definition_requires_it_but_not_provided' do
    assert_equal true, parameter_definition('name', :required => true).missing_required?({})
  end

  test 'should_return_flag_parameter_as_missing_a_value_when_checked_against_a_nil_value' do
    assert_equal true, parameter_definition('name', :required => true).missing_required?('name' => nil)
  end

  test 'should_return_flag_parameter_as_missing_a_value_when_checked_against_an_empty_value' do
    assert_equal true, parameter_definition('name', :required => true).missing_required?('name' => '')
  end

  test 'required_parameter_definitions_are_initially_shown' do
    assert_to_json({
      'name' => 'name',
      'required' => true,
      'default' => nil,
      'initially_shown' => true,
      'initial_value' => nil,
      'allowed_values' => [],
      'multiple_values_allowed' => false,
      'input_type' => 'textbox'
    }, parameter_definition('name', :required => true))
  end

  test 'missing_required_returns_false_if_no_requirement_specs_provided' do
    parameter_defintion = Macro::ParameterDefinition.new('name')
    assert_equal false, parameter_defintion.missing_required?('name' => nil)
  end

  test 'optional_params_with_default_value_are_not_initially_shown' do
    assert_to_json({
      'name' => 'name',
      'required' => false,
      'default' => 'foo',
      'initially_shown' => false,
      'initial_value' => nil,
      'allowed_values' => [],
      'multiple_values_allowed' => false,
      'input_type' => 'textbox'
    }, parameter_definition('name', :default => 'foo'))
  end

  test 'optional_params_with_default_value_can_be_initially_shown' do
    assert_to_json({
      'name' => 'name',
      'required' => false,
      'default' => 'foo',
      'initially_shown' => true,
      'initial_value' => nil,
      'allowed_values' => [],
      'multiple_values_allowed' => false,
      'input_type' => 'textbox'
    }, Macro::ParameterDefinition.new('name', :default => 'foo', :initially_shown => true))
  end

  test 'params_which_are_list_of_series_provide_information_about_individual_series' do
    parameterized_thing = Class.new
    parameterized_thing.send :include, Macro::ParameterSupport
    parameterized_thing.instance_eval do
      parameter 'label', :required => true
      parameter 'value'
    end

    expected_json_hash = {
        'name' => 'name',
        'required' => false,
        'default' => 'foo',
        'initially_shown' => true,
        'initial_value' => nil,
        'allowed_values' => [],
        'multiple_values_allowed' => false,
        'input_type' => 'textbox',
        'list_of' => [
            {
                'name' => 'label',
                'required' => true,
                'default' => nil,
                'initially_shown' => true,
                'initial_value' => nil,
                'allowed_values' => [],
                'multiple_values_allowed' => false,
                'input_type' => 'textbox'
            },

            {
                'name' => 'value',
                'required' => false,
                'default' => nil,
                'initially_shown' => false,
                'initial_value' => nil,
                'allowed_values' => [],
                'multiple_values_allowed' => false,
                'input_type' => 'textbox'
            }
        ]
    }

    assert_to_json(expected_json_hash, Macro::ParameterDefinition.new('name', :default => 'foo', :initially_shown => true, :list_of => parameterized_thing))
  end

  def assert_to_json(expected_json_hash, param_definition)
    assert_equal expected_json_hash, param_definition.to_hash
  end

  test 'resolve_value_returns_default_if_missing' do
    assert_equal 'default value', parameter_definition('name', :default => 'default value').resolve_value({})
  end

  test 'resolve_value_returns_default_if_provided_value_is_nil' do
    assert_equal 'default value', parameter_definition('name', :default => 'default value').resolve_value({'name' => nil})
  end

  test 'resolve_value_returns_default_if_provided_value_is_blank' do
    assert_equal 'default value', parameter_definition('name', :default => 'default value').resolve_value({'name' => ''})
  end

  test 'resolve_value_returns_default_if_provided_value_is_only_spaces' do
    assert_equal 'default value', parameter_definition('name', :default => 'default value').resolve_value({'name' => ' '})
  end

  test 'resolve_value_returns_actual_value_if_provided' do
    assert_equal 'provided', parameter_definition('name', :default => 'default value').resolve_value({'name' => 'provided'})
  end

  test 'resolve_value_returns_stripped_value_if_value_is_string_with_spaces' do
    assert_equal 'provided', parameter_definition('name', :default => 'default value').resolve_value({'name' => '  provided  '})
  end

  test 'resolve_value_can_return_numbers' do
    assert_equal 8, parameter_definition('step', :default => 8).resolve_value({})
    assert_equal 9, parameter_definition('step', :default => 8).resolve_value({'step' => 9})
  end

  test 'resolve_value_returns_numbers_when_provided_plv_can_be_recognized_as_a_number' do
    create_plv!(@project, :name => 'my_numeric_text', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '8')
    create_plv!(@project, :name => 'my_number',       :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '9')

    assert_equal 8, parameter_definition('parameter', :default => 1, :computable => true, :compatible_types => [:string]).resolve_value({ 'parameter' => '(my_numeric_text)' })
    assert_equal 9, parameter_definition('parameter', :default => 1, :computable => true, :compatible_types => [:numeric]).resolve_value({ 'parameter' => '(my_number)' })
  end

  test 'resolve_values_can_return_booleans' do
    assert_equal true,  parameter_definition('links', :default => true).resolve_value({})
    assert_equal true,  parameter_definition('links', :default => false).resolve_value('links' => true)
    assert_equal false, parameter_definition('links', :default => true).resolve_value('links' => false)
  end

  test 'resolve_values_returns_booleans_when_provided_plv_can_be_recognized_as_a_boolean' do
    create_plv!(@project, :name => 'my_true_lower',  :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'true')
    create_plv!(@project, :name => 'my_True_mixed',  :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'True')
    create_plv!(@project, :name => 'my_TRUE_upper',  :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'TRUE')
    create_plv!(@project, :name => 'my_false_lower', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'false')
    create_plv!(@project, :name => 'my_False_mixed', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'False')
    create_plv!(@project, :name => 'my_FALSE_upper', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'FALSE')
    create_plv!(@project, :name => 'my_foo',   :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'foo')
    create_plv!(@project, :name => 'my_bar',   :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'bar')

    assert_equal true,  parameter_definition('links', :default => false, :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_true_lower)')
    assert_equal true,  parameter_definition('links', :default => false, :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_True_mixed)')
    assert_equal true,  parameter_definition('links', :default => false, :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_TRUE_upper)')
    assert_equal false, parameter_definition('links', :default => true,  :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_false_lower)')
    assert_equal false, parameter_definition('links', :default => true,  :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_False_mixed)')
    assert_equal false, parameter_definition('links', :default => true,  :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_FALSE_upper)')
    assert_equal 'foo', parameter_definition('links', :default => true,  :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_foo)')
    assert_equal 'bar', parameter_definition('links', :default => false, :computable => true, :compatible_types => [:string]).resolve_value('links' => '(my_bar)')
  end

  test 'resolve_value_returns_plv_value_when_provided_value_is_a_plv' do
    create_plv!(@project, :name => 'Variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'timmy')
    pd = parameter_definition('column', :computable => true, :compatible_types => [:string])
    assert_equal 'timmy', pd.resolve_value({'column' => '(Variable)'})
  end

  test 'resolve_value_raise_error_if_plv_types_provided_is_not_supported' do
    create_plv!(@project, :name => 'Variable', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100')
    pd = parameter_definition('column', :computable => true, :compatible_types => [:string])
    assert_raise RuntimeError do
      pd.resolve_value({'column' => '(Variable)'})
    end
  end

  test 'resolve_value_returns_provided_value_if_there_is_no_plv_with_that_name' do
    assert_equal '(not a plv)', parameter_definition('column', :computable => true, :compatible_types => [:string]).resolve_value({'column' => '(not a plv)'})
  end

  test 'resolve_value_does_not_try_to_get_plv_value_when_no_plvs_allowed' do
    create_plv!(@project, :name => 'a plv', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '100')
    assert_equal '(a plv)', parameter_definition('column').resolve_value({'column' => '(a plv)'})
  end

  test 'resolve_value_uses_property_when_property_keyword_used' do
    with_new_project do |project|
      setup_property_definitions '(same name)' => []
      create_plv!(project, :name => 'same name', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'not the property definition')
      column_pd = parameter_definition('column', :computable => true, :compatible_types => [:string])
      assert_equal 'not the property definition', column_pd.resolve_value('column' => '(same name)')
      assert_equal '(same name)', column_pd.resolve_value('column' => 'PROPERTY (same name)')
    end
  end

  test 'user_plvs_should_show_the_user_name' do
    create_plv(@project, :name => 'my_user', :data_type => ProjectVariable::USER_DATA_TYPE, :value => User.find_by_login('member').id)
    assert_equal 'member@email.com', parameter_definition('parameter', :computable => true, :compatible_types => [:user]).resolve_value({'parameter' => '(my_user)'})
  end

  test 'card_plvs_should_show_the_card_number_and_name' do
    create_plv(@project, :name => 'my_card', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => @card.id)
    assert_equal @card.number_and_name, parameter_definition('parameter', :computable => true, :compatible_types => [:card]).resolve_value({'parameter' => '(my_card)'})
  end

  test 'resolve_value_should_return_default_value_when_plv_is_not_set' do
    create_plv(@project, :name => 'my_user', :data_type => ProjectVariable::USER_DATA_TYPE, :value => nil)
    assert_equal 'member', parameter_definition('parameter', :computable => true, :compatible_types => [:user], :default => 'member').resolve_value({'parameter' => '(my_user)'})
  end

  test 'should_tell_example' do
    assert_equal 'SELECT number, name', Macro::ParameterDefinition.new('name', :required => true, :example => 'SELECT number, name').example
  end

  test 'should_resolve_series_parameter_into_a_list_of_series_objects' do
    with_data_series_chart_project do |project|
      template = %{ {{
        data-series-chart
          cumulative: true
          type: bar
          series:
            - label       : oh
              data        : SELECT 'Development Complete Iteration', SUM(Size)
            - label       : hai
              data        : SELECT 'Analysis Complete Iteration', SUM(Size)
      }} }
      chart = Chart.extract(template, 'data-series', 1)

      param = Macro::ParameterDefinition.new('series', :required => true, :list_of => Series)

      expected_series = [
        Series.new(chart, 'data' => "SELECT 'Development Complete Iteration', SUM(Size)", 'label' => 'oh'),
        Series.new(chart, 'data' => "SELECT 'Analysis Complete Iteration', SUM(Size)", 'label' => 'hai')
      ]

      actual_series = param.resolve_value({'series' => [
        {'data' => "SELECT 'Development Complete Iteration', SUM(Size)", 'label' => 'oh'},
        {'data' => "SELECT 'Analysis Complete Iteration', SUM(Size)", 'label' => 'hai'}]},
        nil, chart
      )

      assert_equal expected_series, actual_series
    end
  end

  test 'should_resolve_builtin_string_property_of_THIS_CARD' do
    assert_equal @card.name, Macro::ParameterDefinition.new('name', :computable => true).resolve_value({'name' => 'THIS CARD.name'}, @card)
  end

  test 'should_resolve_builtin_integer_property_of_THIS_CARD' do
    assert_equal @card.number, Macro::ParameterDefinition.new('number', :computable => true).resolve_value({'number' => 'THIS CARD.number'}, @card)
  end

  test 'should_resolve_builtin_project_property_of_THIS_CARD' do
    assert_equal @card.project.name, Macro::ParameterDefinition.new('project', :computable => true).resolve_value({'project' => 'THIS CARD.project'}, @card)
  end

  test 'should_resolve_string_property_of_THIS_CARD' do
    @card.update_attribute(:cp_status, 'open')
    assert_equal 'open', Macro::ParameterDefinition.new('status', :computable => true).resolve_value({'status' => 'THIS CARD.status'}, @card)
  end

  test 'should_resolve_numeric_property_of_THIS_CARD' do
    @card.update_attribute(:cp_release, 1)
    assert_equal 1, Macro::ParameterDefinition.new('Release', :computable => true).resolve_value({'Release' => 'THIS CARD.Release'}, @card)
  end

  test 'should_resolve_user_property_of_THIS_CARD' do
    member = User.find_by_login('member')
    @card.update_attribute(:cp_dev, member)
    assert_equal member.name, Macro::ParameterDefinition.new('dev', :computable => true).resolve_value({'dev' => 'THIS CARD.dev'}, @card)
  end

  test 'should_resolve_card_property_of_THIS_CARD' do
    with_three_level_tree_project do |project|
      iteration = create_card!(:name => 'iteration', :type => 'iteration')
      story = create_card!(:name => 'story', :type => 'story')
      story.update_attribute(:cp_related_card, iteration)
      assert_equal "##{iteration.number} #{iteration.name}", Macro::ParameterDefinition.new('related card', :computable => true).resolve_value({'related card' => 'THIS CARD.related card'}, story)
    end
  end

  test 'should_resolve_formula_property_of_THIS_CARD' do
    with_new_project do |project|
      card = create_card!(:name => 'card')
      one_eighth = setup_formula_property_definition('one eighth', '1/8')
      card.reload
      assert_equal 0.13, Macro::ParameterDefinition.new('width', :computable => true).resolve_value({'width' => 'THIS CARD.one eighth'}, card)
    end
  end

  test 'should_resolve_aggregate_property_of_THIS_CARD' do
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')
      compute_aggregate_for_single_card(iteration1, 'sum of size')
      iteration1.reload
      assert_equal 4, Macro::ParameterDefinition.new('size', :computable => true).resolve_value({'size' => 'THIS CARD.sum of size'}, iteration1)
    end
  end

  test 'resolve_value_should_return_parameter_default_value_when_THIS_CARD_property_value_is_not_set' do
    @card.update_attribute(:cp_status, nil)
    assert_equal 'open', Macro::ParameterDefinition.new('status', :computable => true, :default => 'open').resolve_value({'status' => 'THIS CARD.status'}, @card)
  end

  test 'resolve_value_should_raise_error_when_property_of_THIS_CARD_not_match_with_type_expected' do
    @card.update_attribute(:cp_release, 1)
    e = assert_raise(RuntimeError) do
      Macro::ParameterDefinition.new('status', :computable => true, :compatible_types => [:string]).resolve_value({'status' => 'THIS CARD.Release'}, @card)
    end
    assert_equal "Data types for parameter #{'status'.bold} and #{'THIS CARD.Release'.bold} do not match. Please enter the valid data type for #{'status'.bold}.", e.message
  end

  test 'resolve_value_should_raise_error_when_property_value_is_not_set_and_property_type_of_THIS_CARD_unmatch' do
    @card.update_attribute(:cp_status, nil)
    assert_raise(RuntimeError) do
      Macro::ParameterDefinition.new('start date', :computable => true, :compatible_types => [:date], :default => '2010-01-26').resolve_value({'start date' => 'THIS CARD.status'}, @card)
    end
  end

  test 'should_accept_procs_for_initial_value_and_values' do
    current_project_identifier = Proc.new {Project.current.identifier}
    values = Proc.new {[1, 2, 3]}
    param_def = Macro::ParameterDefinition.new(:project, values: values, initial_value: current_project_identifier, required: true, type: SimpleParameterInput.new('single_select_parameter_input'))
    with_new_project do |p|
      assert_equal(p.identifier, param_def.initial_value)
      assert_equal([1, 2, 3], param_def.allowed_values)
    end
  end

  test 'should_raise_error_when_content_provide_is_page' do
    e = assert_raise(CardQuery::DomainException) do
      Macro::ParameterDefinition.new('status', :computable => true).resolve_value({'status' => 'THIS CARD.Release'}, @project.pages.first)
    end
    assert_equal "#{'THIS CARD.Release'.bold} is not a supported macro for page.", e.message
  end

  test 'should_raise_error_when_content_provide_is_card_default' do
    receiver = MockAlertReceiver.new
    Macro::ParameterDefinition.new('status', :computable => true).resolve_value({'status' => 'THIS CARD.Release'}, @card.card_type.card_defaults, receiver)
    assert_equal ["Macros using #{'THIS CARD.Release'.bold} will be rendered when card is created using this card default."], receiver.alerts
  end

  test 'should_know_computed_property_values' do
    @card.update_attribute(:cp_status, 'open')
    parameter_definition = Macro::ParameterDefinition.new('status', :computable => true, :default => 'open')
    parameter_definition.resolve_value({'status' => 'THIS CARD.status'}, @card)
    assert_equal 'open', parameter_definition.this_card_property_display_value_resolved

    parameter_definition = Macro::ParameterDefinition.new('status', :computable => true, :default => 'open')
    parameter_definition.resolve_value({'status' => 'open'}, @card)
    assert_equal nil, parameter_definition.this_card_property_display_value_resolved

    create_plv(@project, :name => 'my_user', :data_type => ProjectVariable::USER_DATA_TYPE, :value => nil)
    parameter_definition = parameter_definition('parameter', :computable => true, :compatible_types => [:user], :default => 'member')
    parameter_definition.resolve_value({'parameter' => '(my_user)'})
    assert_equal nil, parameter_definition.this_card_property_display_value_resolved
  end

  test 'display_name_should_humanize_the_param_name' do
    assert_equal 'Card type', parameter_definition(:card_type).display_name
  end

  test 'should_have_allowed_values_in_hash' do
    allowed_values = %w(val1 val2)
    param_definition = Macro::ParameterDefinition.new('status', :computable => true, :default => 'open', values: allowed_values)
    assert_equal(allowed_values, param_definition.to_hash['allowed_values'])
  end

  test 'should_have_multiple_values_allowed_in_hash' do
    param_definition = Macro::ParameterDefinition.new('status', :computable => true, :default => 'open', type: SimpleParameterInput.new('foo_multi_blah'))
    assert param_definition.to_hash['multiple_values_allowed']

    param_definition = Macro::ParameterDefinition.new('status', :computable => true, :default => 'open', type: SimpleParameterInput.new('foo_bar'))

    assert_false param_definition.to_hash['multiple_values_allowed']
  end

  test 'easy_charts_should_be_set' do
    param_definition = Macro::ParameterDefinition.new('status', :computable => true, :default => 'open', :easy_charts => true)

    assert param_definition.easy_charts?
  end

  test 'easy_charts_should_return_false_when_not_set' do
    param_definition = Macro::ParameterDefinition.new('status', :computable => true, :default => 'open')

    assert_false param_definition.easy_charts?
  end

  test 'should_set_value_to_default_when_not_present_in_allowed_values' do
    resolved_value = Macro::ParameterDefinition.new('status', :computable => true, :default => 'default', :values => %w(new done)).resolve_value({'status' => 'invalid'}, @project.pages.first)
    assert_equal('default', resolved_value)
  end

  test 'should_accept_valid_values_with_case_insensitivity' do
    resolved_value = Macro::ParameterDefinition.new('status', :computable => true, :default => 'default', :values => %w(new done)).resolve_value({'status' => 'NeW'}, @project.pages.first)
    assert_equal('new', resolved_value)
  end

  test 'display_name_should_return_overridden_name_when_present' do
    display_name = 'Display Name For Status'

    assert_equal(display_name, Macro::ParameterDefinition.new(:status, display_name: display_name).display_name)
  end

  test 'should_be_able_to_resolve_proc_defaults' do
    assert_equal('foobar', Macro::ParameterDefinition.new(:name, default: Proc.new { 'foo' + 'bar' }).default)
  end

  private #helper methods
  def parameter_definition(name, options = {})
    Macro::ParameterDefinition.new(name, options)
  end

  class MockAlertReceiver
    attr_reader :alerts

    def initialize
      @alerts = []
    end

    def alert(message)
      alerts << message
    end
  end

end
