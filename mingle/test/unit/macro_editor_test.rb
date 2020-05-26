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

class MacroEditorTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @first_card = @project.cards.first
    login_as_member
  end

  def test_should_support_macros_which_need_parameters
    assert_include 'table-query', MacroEditor.supported_macros.collect(&:name)
  end

  def test_should_generate_table_query
    editor = MacroEditor.new(@project, 'table-query', {:query => 'SELECT number,name'})
    assert_equal_ignoring_spaces '{{table query: SELECT number,name}}', editor.content
  end

  def test_should_generate_pivot_table_with_required_params_even_if_the_example_is_blank
    editor = MacroEditor.new(@project, 'pivot-table', {})
    expected_macro_content = <<-EXPECTED
      {{
        pivot-table
          columns:
          rows:
      }}
    EXPECTED
    assert_equal_ignoring_spaces expected_macro_content, editor.content
  end

  def test_should_remove_closing_macro_markup_from_macro
    editor = MacroEditor.new(@project, 'table-view', {'view' => 'invalid view name }} fooo }}'})
    expected_macro_content = <<-EXPECTED
      {{
        table
          view: invalid view name fooo
      }}
    EXPECTED
    assert_equal_ignoring_spaces expected_macro_content, editor.content_with_example
  end

  def test_should_generate_stack_bar_chart
    editor = MacroEditor.new(@project, 'stack-bar-chart', {'series' => {'0' => {'data' => 'type=Story', 'label' => 'Series 1'}, '1' => {'data' => 'type=Bug', 'label' => 'Series 2'}}})
    assert_equal_ignoring_spaces <<-EXPECTED, editor.content
      {{
        stack-bar-chart
          series:
          - data: type=Story
            label: Series 1
          - data: type=Bug
            label: Series 2
      }}
    EXPECTED
  end

  def test_should_generate_stack_bar_chart_when_series_is_an_array
    editor = MacroEditor.new(@project, 'stack-bar-chart', {'series' => [{'data' => 'type=Story', 'label' => 'Series 1'}, {'data' => 'type=Bug', 'label' => 'Series 2'}]})
    assert_equal_ignoring_spaces <<-EXPECTED, editor.content
      {{
        stack-bar-chart
          series:
          - data: type=Story
            label: Series 1
          - data: type=Bug
            label: Series 2
      }}
    EXPECTED
  end

  def test_should_generate_daily_history_chart
    editor = MacroEditor.new(@project, 'daily-history-chart', { 'aggregate' => 'SUM (estimate)', 'chart-conditions' => 'type = card', 'series' => {'0' => {'conditions' => 'type=Story', 'label' => 'Series 1'}}})
    assert_equal_ignoring_spaces <<-EXPECTED, editor.content
      {{
        daily-history-chart
          aggregate: SUM (estimate)
          start-date:
          end-date:
          chart-conditions: type = card
          series:
          - conditions: type=Story
            label: Series 1
      }}
    EXPECTED
  end

  def test_should_get_rid_of_blank_parameter_values
    editor = MacroEditor.new(@project, 'table-query', {:query => 'SELECT number,name', :view => ''})
    assert_equal_ignoring_spaces '{{table query: SELECT number,name}}', editor.content
  end

  def test_should_tell_parameters_of_table_query
    table_query_def = MacroEditor.macro_def_for 'table-query'

    query_parameter = table_query_def.parameter_definitions.first
    assert_equal 'query', query_parameter.name
    assert query_parameter.required?
  end

  def test_should_tell_parameters_of_table_view
    table_view_def = MacroEditor.macro_def_for 'table-view'

    view_parameter = table_view_def.parameter_definitions.first
    assert_equal 'view', view_parameter.name
    assert view_parameter.required?
  end

  def test_should_have_project_parameter_at_last_of_macro_parameters
    table_view_def = MacroEditor.macro_def_for 'table-view'
    project_parameter = table_view_def.parameter_definitions.last
    assert_equal 'project', project_parameter.name.to_s
    assert !project_parameter.required?
  end

  def test_project_should_be_in_specific_position_of_pivot_table_macro_parameters_definitions
    pivot_table_def = MacroEditor.macro_def_for 'pivot-table'
    project_parameter = pivot_table_def.parameter_definitions.at(4)
    assert_equal 'project', project_parameter.name.to_s
    assert !project_parameter.required?
  end

  def test_project_should_be_in_specific_position_of_pie_chart_macro_parameters_definitions
    pie_chart_def = MacroEditor.macro_def_for 'pie-chart'
    project_parameter = pie_chart_def.parameter_definitions.at(1)
    assert_equal 'project', project_parameter.name.to_s
    assert !project_parameter.required?
  end

  def test_should_support_project_macro
    project_macro_def = MacroEditor.macro_def_for 'project'
    assert_equal 1, project_macro_def.parameter_definitions.size
  end

  def test_macro_parameter_shold_split_by_dash_instead_of_understore
    macro_def = MacroEditor.macro_def_for 'ratio-bar-chart'
    restrict_ratio_with_param = macro_def.parameter_definitions.find{|param| param.name == :restrict_ratio_with}
    assert_equal 'restrict-ratio-with', restrict_ratio_with_param.parameter_name
  end

  def test_editor_recognizes_stacked_bar_chart_macro
    assert_equal 'stack-bar-chart', MacroEditor.macro_def_for('stack-bar-chart').name
    assert_include 'project', MacroEditor.macro_def_for('stack-bar-chart').parameter_definitions.map(&:name).map(&:to_s)
  end

  def test_editor_recognizes_cumulative_flow_graph_macro
    assert_equal 'cumulative-flow-graph', MacroEditor.macro_def_for('cumulative-flow-graph').name
    assert_include 'project', MacroEditor.macro_def_for('cumulative-flow-graph').parameter_definitions.map(&:name).map(&:to_s)
  end

  def test_editor_presents_parameters_in_preferred_order
    assert_equal 'stack-bar-chart', MacroEditor.macro_def_for('stack-bar-chart').name
    expected_first_four_params = %w(conditions cumulative x-label-start x-label-end)
    actual_first_four_params = MacroEditor.macro_def_for('stack-bar-chart').parameter_definitions.map(&:parameter_name)[0..3].map(&:to_s)
    assert_equal expected_first_four_params, actual_first_four_params
  end

  def test_ratio_bar_chart_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('ratio-bar-chart')
    expected_parameter_name = %w{totals restrict-ratio-with color x-title y-title three-d title
 show-guide-lines chart-size chart-height chart-width plot-height plot-width plot-x-offset plot-y-offset label-font-angle project}

    assert_equal expected_parameter_name, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_pie_chart_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('pie-chart')
    sorted_param_defs = %w(data project chart-width chart-height radius title chart-size label-type legend-position)

    assert_equal sorted_param_defs, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_table_query_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('table-query')
    assert_equal %w{query project edit-any-number-property}, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_table_view_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('table-view')
    assert_equal %w{view project}, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_average_macro_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('average')
    assert_equal %w{query project}, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_value_macro_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('value')
    assert_equal %w{query project}, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_project_variable_macro_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('project-variable')
    assert_equal %w{name project}, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_project_macro_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('project')
    assert_equal %w{project}, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_pivot_table_parameters_should_sort_as_bonnas_required
    macro_def = MacroEditor.macro_def_for('pivot-table')
    assert_equal %w{columns
    rows
    conditions
    aggregation
    project
    totals
    empty-columns
    empty-rows
    links}, macro_def.parameter_definitions.collect(&:parameter_name)
  end

  def test_ratio_bar_chart_requied_parameters_should_have_example
    macro_def = MacroEditor.macro_def_for('ratio-bar-chart')
    totals = macro_def.parameter_definitions.find{|param| param.name == :totals}
    restrict_ratio_with = macro_def.parameter_definitions.find{|param| param.name == :restrict_ratio_with}
    assert_equal 'SELECT property, aggregate WHERE condition', totals.example
    assert_equal 'condition', restrict_ratio_with.example
  end

  def test_data_series_chart_should_have_example
    macro_def = MacroEditor.macro_def_for('data-series-chart')
    conditions = macro_def.parameter_definitions.find{|param| param.name == :conditions}
    cumulative = macro_def.parameter_definitions.find{|param| param.name == :cumulative}
    assert_equal 'type = card_type', conditions.example
  end

  def test_stack_bar_chart_should_have_example
    macro_def = MacroEditor.macro_def_for('stack-bar-chart')
    conditions = macro_def.parameter_definitions.find{|param| param.name == :conditions}
    cumulative = macro_def.parameter_definitions.find{|param| param.name == :cumulative}
    assert_equal 'type = card_type', conditions.example
  end

  def test_preview_table_query_macro
    editor = MacroEditor.new(@project, 'table-query', {:query => 'SELECT number, name where number < 4'}, {:provider_type => 'Card', :id => @first_card.id})
    assert_equal_ignoring_spaces %{
<table><tbody><tr>
    <th>number</th>
    <th>name</th>
  </tr>
  <tr>
    <td><a href=\"/projects/first_project/cards/1\">1</a></td>
    <td><a href=\"/projects/first_project/cards/1\">firstcard</a></td>
  </tr></tbody></table>},
    editor.preview(view_helper)
  end

  #bug #12596
  def test_preview_table_query_macro_with_new_card
    editor = MacroEditor.new(@project, 'table-query', {:query => 'SELECT number, name where number < 4'}, {:provider_type => 'Card', :id => nil})
    assert_equal_ignoring_spaces %{
<table><tbody><tr>
    <th>number</th>
    <th>name</th>
  </tr>
  <tr>
    <td><a href=\"/projects/first_project/cards/1\">1</a></td>
    <td><a href=\"/projects/first_project/cards/1\">firstcard</a></td>
  </tr></tbody></table>},
    editor.preview(view_helper)
  end

  # bug 7889
  def test_previewing_stack_bar_chart_without_series_data_should_not_result_in_500
    editor = MacroEditor.new(@project, 'stack-bar-chart', { :conditions => 'hi there' }, { :provider_type => 'Card', :id => @first_card.id })
    assert_match Regexp.new("Error in stack-bar-chart macro: Parameter #{'series'.bold} is required."), editor.preview(view_helper)
  end

  def test_preview_table_query_macro_in_page
    editor = MacroEditor.new(@project, 'table-query', {:query => 'SELECT number, name where number < 4'}, {:provider_type => 'Page', :id => @project.pages.first.id})
    assert_equal_ignoring_spaces %{
<table><tbody><tr>
    <th>number</th>
    <th>name</th>
  </tr>
  <tr>
    <td><a href=\"/projects/first_project/cards/1\">1</a></td>
    <td><a href=\"/projects/first_project/cards/1\">firstcard</a></td>
  </tr></tbody></table>},
    editor.preview(view_helper)
  end

  # bug 7794
  def test_preview_table_query_macro_in_card_default
      type_card = @project.card_types.find_by_name('Card')
      assert type_card.card_defaults

      editor = MacroEditor.new(@project, 'table-query', {:query => 'SELECT number, name where number < 4'}, {:provider_type => 'CardDefaults', :id => type_card.card_defaults.id})
      assert_equal_ignoring_spaces %{
  <table><tbody><tr>
      <th>number</th>
      <th>name</th>
    </tr>
    <tr>
      <td><a href=\"/projects/first_project/cards/1\">1</a></td>
      <td><a href=\"/projects/first_project/cards/1\">firstcard</a></td>
    </tr></tbody></table>},
      editor.preview(view_helper)
  end

  def test_preview_table_query_macro_on_new_page
    editor = MacroEditor.new(@project, 'table-query', {:query => 'SELECT number, name where number < 4'}, {:provider_type => 'Page', :id => nil})
    assert_equal_ignoring_spaces %{
    <table><tbody><tr>
        <th>number</th>
        <th>name</th>
      </tr>
      <tr>
        <td><a href=\"/projects/first_project/cards/1\">1</a></td>
        <td><a href=\"/projects/first_project/cards/1\">firstcard</a></td>
      </tr></tbody></table>}, editor.preview(view_helper)
  end

  def test_should_generate_correct_content_for_macro_without_parameter
    editor = MacroEditor.new(@project, 'project', {}, {:provider_type => 'Page'})
    assert_equal_ignoring_spaces @project.identifier, editor.preview(view_helper)
  end

  def test_preview_macro_with_this_card_syntax
    with_card_query_project do |project|
      bar = create_card!(:name => 'bar')
      foo = create_card!(:name => 'foo', :'related card' => bar.id)
      editor = MacroEditor.new(project, 'value', {:query => "SELECT name WHERE 'related card' = this card"}, { :provider_type => 'Card', :id => bar.id})
      assert_include 'foo', editor.preview(view_helper)
    end
  end

  def test_macro_definition_to_json_provides_info_about_parameter_definitions
    macro_def = MacroEditor::MacroDef.new(
      'badri', [
        Macro::ParameterDefinition.new('query', :required => true, :initial_value => 'hello'),
        Macro::ParameterDefinition.new('jimmy', :default => 'default_value', :initially_shown => true)
      ]
    )

    expected = {
      'badri' => [
          { 'name' => 'query'   , 'required' => true  , 'default' => nil              , 'initially_shown' => true, 'initial_value' => 'hello','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
          { 'name' => 'jimmy'   , 'required' => false , 'default' => 'default_value'  , 'initially_shown' => true, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'  }
        ]
    }
    assert_equal expected, macro_def.to_hash
  end

  def test_macro_editor_to_json_provides_info_about_parameter_definitions_for_all_macros
    json_macro_definition = MacroEditor::macro_as_json('pivot-table')
    expected_json_params_for_pivot_table_macro = [ {'name' => 'columns',       'initially_shown' => true,  'required' => true,      'default' => nil, 'initial_value' => nil, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox' },
                                                   {'name' => 'rows',          'initially_shown' => true,  'required' => true,      'default' => nil, 'initial_value' => nil, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox' },
                                                   {'name' => 'conditions',    'initially_shown' => true,  'required' => false,     'default' => '', 'initial_value' => nil, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox' },
                                                   {'name' => 'aggregation',   'initially_shown' => true,  'required' => false,     'default' => 'COUNT(*)', 'initial_value' => nil, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox' },
                                                   {'name' => 'project',       'initially_shown' => false, 'required' => false,     'default' => nil, 'initial_value' => nil, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox' },
                                                   {'name' => 'totals',        'initially_shown' => true,  'required' => false,     'default' => false, 'initial_value' => false, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button' },
                                                   {'name' => 'empty-columns', 'initially_shown' => true,  'required' => false,     'default' => true, 'initial_value' => true, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button' },
                                                   {'name' => 'empty-rows',    'initially_shown' => true,  'required' => false,     'default' => true, 'initial_value' => true, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button' },
                                                   {'name' => 'links',         'initially_shown' => false, 'required' => false,     'default' => true, 'initial_value' => true, 'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'} ]
    actual_json = ActiveSupport::JSON.decode(json_macro_definition)['pivot-table']
    expected_json_params_for_pivot_table_macro.each_with_index { |line, i| assert_equal actual_json[i], line }
  end

  def test_macro_editor_to_json_provides_info_about_parameter_definitions_for_data_series_series
    json_macro_definition = MacroEditor::macro_as_json('data-series-chart')
    expected_json_params_for_series = [{'name' => 'data', 'required' => true, 'initially_shown' => true, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'label', 'required' => false, 'initially_shown' => true, 'default' => 'Series', 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'color', 'required' => false, 'initially_shown' => true, 'default' => nil, 'initial_value' => '#FF0000','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'type', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => 'bar','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'project', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'data-point-symbol', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => 'none','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'data-labels', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => true,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'down-from', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'line-width', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'line-style', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => 'solid','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'trend', 'required' => false, 'initially_shown' => true, 'default' => nil, 'initial_value' => true,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'trend-scope', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'trend-ignore', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => Series::TREND_IGNORE_ZEROES_AT_END_AND_LAST_VALUE,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'trend-line-color', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => '#FF0000','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'trend-line-style', 'required' => false, 'initially_shown' => false, 'default' => 'dash', 'initial_value' => 'dash','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'trend-line-width', 'required' => false, 'initially_shown' => true, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'}]
    actual_json = ActiveSupport::JSON.decode(json_macro_definition)['data-series-chart-series']
    expected_json_params_for_series.each_with_index { |line, i| assert_equal line, actual_json[i] }
  end

  def test_macro_editor_to_json_provides_info_about_parameter_definitions_for_stack_bar_chart_series
    json_macro_definition = MacroEditor::macro_as_json('stack-bar-chart')
    expected_json_params_for_series = [{'name' => 'data', 'required' => true, 'initially_shown' => true, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'label', 'required' => false, 'initially_shown' => true, 'default' => 'Series', 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'color', 'required' => false, 'initially_shown' => true, 'default' => nil, 'initial_value' => '#FF0000','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'type', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => 'bar','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'project', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => nil,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'textbox'},
                                       {'name' => 'combine', 'required' => false, 'initially_shown' => true, 'default' => nil, 'initial_value' => 'overlay-bottom','allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'},
                                       {'name' => 'hidden', 'required' => false, 'initially_shown' => false, 'default' => nil, 'initial_value' => false,'allowed_values' => [],'multiple_values_allowed' => false, 'input_type' => 'radio_button'}]
    actual_json = ActiveSupport::JSON.decode(json_macro_definition)['stack-bar-chart-series']
    expected_json_params_for_series.each_with_index { |line, i| assert_equal line, actual_json[i] }
  end
end
