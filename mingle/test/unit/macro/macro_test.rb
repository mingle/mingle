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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class MacroTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit

  CHARTS_WITHOUT_SERIES = %w(average pie-chart pivot-table project project-variable ratio-bar-chart table-query table-view value)
  CHARTS_WITH_SERIES = %w(daily-history-chart data-series-chart stack-bar-chart)

  class MacroWithRequiredParameter < Macro
    parameter :name, :required => true
    def execute
      "DUMMY #{name} #{parameters.sort}"
    end
  end

  class DummyMacroNeedRedCloth < Macro
    def execute
      "#{RedCloth.new('|cell|').to_html}__something__"
    end
  end

  class AccessPropertyDefinitionsFromCardTypeCustomMacro
    def initialize(parameters, project, current_user=nil)
      @project = project
    end

    def execute
      @project.card_types.first.property_definitions
      "Hello world"
    end
  end

  class AccessCardTypesFromPropertyDefinitionsCustomMacro
    def initialize(parameters, project, current_user=nil)
      @project = project
    end

    def execute
      @project.property_definitions.last.card_types
      "Hello world"
    end
  end

  class PredefinedPropertiesApplyToAllCardTypesCustomMacro
    def initialize(parameters, project, current_user=nil)
      @type = parameters['type']
      @project = project
    end

    def execute
      @project.property_definitions.detect { |pd| pd.name == @type }.card_types.collect(&:name).sort.to_s
    end
  end

  class ComputableMacro < Macro
    parameter :name, :required => true, :computable => true
  end

  def test_macro_renders_this_card_alerts_as_warnings
    with_built_in_macro_registered('computable', ComputableMacro) do
      login_as_member
      with_first_project do |project|
        card = project.cards.new
        card.description = <<-MACRO
          {{
            computable
              name: THIS CARD.Material
          }}
        MACRO
        assert card.macro_execution_errors.empty?
        actual = card.formatted_content_preview(view_helper).normalize_whitespace
        assert_equal "Macros using #{"THIS CARD.Material".bold} will be rendered when card is saved.", actual
      end
    end
  end

  def test_predefined_properties_should_apply_to_all_card_types
    with_custom_macro_registered('dummy', PredefinedPropertiesApplyToAllCardTypesCustomMacro) do
      login_as_member
      with_three_level_tree_project do |project|
        project.predefined_property_definitions.collect(&:name).each do |predefined_property|
          card = project.cards.first
          card.update_attribute :description, "{{ dummy type: #{predefined_property}}}"
          assert_equal_ignoring_spaces project.card_types.collect(&:name).sort.to_s, card.formatted_content_preview(self)
        end
      end
    end
  end

  def test_should_be_able_to_access_property_definitions_from_card_type
    with_custom_macro_registered('dummy', AccessPropertyDefinitionsFromCardTypeCustomMacro) do
      login_as_member
      with_card_query_project do |project|
        card = project.cards.first
        card.update_attribute :description, '{{ dummy }}'
        assert_equal_ignoring_spaces "Hello world", card.formatted_content_preview(self)
      end
    end
  end

  def test_should_be_able_to_access_card_types_from_property_definitions
    with_custom_macro_registered('dummy', AccessCardTypesFromPropertyDefinitionsCustomMacro) do
      login_as_member
      with_card_query_project do |project|
        card = project.cards.first
        card.update_attribute :description, '{{ dummy }}'
        assert_equal_ignoring_spaces "Hello world", card.formatted_content_preview(self)
      end
    end
  end

  def test_should_be_able_to_apply_redcloth_in_macro
    Macro.register('timmy', DummyMacroNeedRedCloth)
    login_as_member
    with_card_query_project do |project|
      some_page = project.pages.create!(:name => "some page", :content => <<-CONTENT)
      {{ timmy }}
      CONTENT
      expected = %{<table><tbody><tr><td>cell</td></tr></tbody></table>__something__}
      assert_equal expected, some_page.formatted_content(view_helper).strip_all
    end
  ensure
    Macro.unregister('timmy')
  end

  def test_card_query_options_does_set_content_provider_parameter_when_content_provider_is_a_page
    login_as_member
    with_card_query_project do |project|
      some_page = project.pages.create!(:name => "some page")
      macro = DummyMacro.new({:project => project, :content_provider => some_page}, 'name', {})
      assert_equal some_page, macro.card_query_options[:content_provider]
    end
  end

  def test_card_query_options_set_content_provider_parameter_when_content_provider_is_a_card
    login_as_member
    with_card_query_project do |project|
      some_card = create_card!(:name => 'some card')
      macro = DummyMacro.new({:project => project, :content_provider => some_card}, 'name', {})
      assert_equal some_card, macro.card_query_options[:content_provider]
    end
  end

  def test_creating_registered_macro
    Macro.register('dummy', DummyMacro)
    with_card_query_project do |project|
      macro = Macro.create('dummy', {:project => project}, {}, "")
      assert_equal DummyMacro, macro.class
      assert_equal 'dummy', macro.name
    end
  ensure
    Macro.unregister('dummy')
  end

  def test_should_throw_processing_error_when_try_initialize_non_exist_macro
    with_card_query_project do |project|
      assert_raise(Macro::ProcessingError) { Macro.create('no exist macro', {:project => project}, {}, "")}
    end
  end

  def test_should_return_an_empty_hash_when_parsing_params_from_an_empty_string
    assert_equal({}, Macro.parse_parameters(%{ }))
    assert_equal({}, Macro.parse_parameters(%{
    }))
    assert_equal({}, Macro.parse_parameters(%{

    }))
  end

  def test_should_throw_processing_error_when_failed_to_parse_parameters
    e = assert_raise(Macro::ProcessingError) { Macro.parse_parameters(%{
                                                                        totals: SELECT Feature, SUM(Size) WHERE old_type = Story and Release = '1'
                                                                        restrict
    }) }
    assert_equal Macro::SYNTAX_ERROR_MESSAGE, e.message
  end

  def test_should_throw_processing_error_when_a_required_parameter_does_not_have_its_value_specified
    Macro.register('timmy', MacroWithRequiredParameter)
    e = assert_raise(Macro::ProcessingError) { Macro.create('timmy', {}, {:name => nil}, "")}
    assert_match(/#{'name'.bold} is required/, e.message)
    assert_match(Regexp.new(Regexp.escape(Macro::SYNTAX_ERROR_MESSAGE)), e.message)
  ensure
    Macro.unregister('timmy')
  end

  def test_certain_charts_should_not_include_series_definition_in_their_parameter_definitions
    with_card_query_project do |project|
      CHARTS_WITH_SERIES.each do |macro_name|
        assert_not_include "series", MacroEditor.supported_macros.find { |macro_def| macro_def.name == macro_name }.parameter_definitions.map(&:name)
      end
    end
  end

  def test_certain_charts_should_support_series
    with_card_query_project do |project|
      CHARTS_WITH_SERIES.each do |macro_name|
        assert MacroEditor.supported_macros.find { |macro_def| macro_def.name == macro_name }.support_series?
      end
    end
  end

  def test_certain_charts_should_include_series_parameter_definitions_in_json_representation
    with_card_query_project do |project|
      CHARTS_WITH_SERIES.each do |macro_name|
        assert_not_nil MacroEditor.macro_as_json(macro_name)["#{macro_name}-series"]
      end
    end
  end

  def test_certain_charts_should_not_include_series_parameter_definitions_in_json_representation
    with_card_query_project do |project|
      CHARTS_WITHOUT_SERIES.each do |macro_name|
        assert_nil MacroEditor.macro_as_json(macro_name)["#{macro_name}-series"]
      end
    end
  end

  def test_certain_charts_should_not_support_series
    with_card_query_project do |project|
      CHARTS_WITHOUT_SERIES.each do |macro_name|
        assert_false MacroEditor.supported_macros.find { |macro_def| macro_def.name == macro_name }.support_series?
      end
    end
  end

  def test_macro_def_should_return_series_parameter_definitions_when_it_supports_them
    expected = Series.parameter_definitions
    assert_equal expected, MacroEditor::MacroDef.new('stack-bar-chart', StackBarChart.parameter_definitions, :series_parameter_definitions => expected).series_parameter_definitions
  end

  def test_parse_parameters_should_raise_unless_it_parses_a_hash
    assert_raises(Macro::ProcessingError) { Macro.parse_parameters("1") }
  end

  class DangerousClass
    @@deserialized_by_yaml = false

    def yaml_initialize(tag, val)
      @@deserialized_by_yaml = true
    end

    def self.deserialized_by_yaml
      @@deserialized_by_yaml
    end
  end

  def test_parse_parameters_should_reject_yaml_with_embedded_ruby_types_and_never_instantiate
    assert_raises Macro::ProcessingError do
      Macro.parse_parameters <<-MACRO
        name: !ruby/object:MacroTest::DangerousClass
          first_var: 1
          second_var: 2
      MACRO
    end

    # assert that YAML never even instantiates the class
    assert !DangerousClass.deserialized_by_yaml, "YAML.load() should not have created a DangerousClass instance"
  end
end
