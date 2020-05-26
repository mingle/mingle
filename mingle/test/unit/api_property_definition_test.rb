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

class ApiPropertyDefinitionTest < ActiveSupport::TestCase
  def setup
    @project = create_project()
  end
  
  def test_should_be_able_to_use_project_scope_to_create_api_property_definition
    property_definition = @project.all_property_definitions.create_api_property_definition(:data_type => "string", :is_managed => "true", :name => "Status")
    assert property_definition.valid?
  end
  
  def test_build_managed_text_property_definitions
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "string", :is_managed => "true", :name => "Status")
    assert_equal EnumeratedPropertyDefinition, property_definition.class
    assert_equal "string", property_definition.property_type.to_s
  end
  
  def test_build_managed_numeric_property_definitions
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "numeric", :is_managed => "true", :name => "Iteration")
    assert_equal EnumeratedPropertyDefinition, property_definition.class
    assert_equal "numeric", property_definition.property_type.to_s
  end

  def test_build_unmanaged_numeric_property_definitions
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "numeric", :is_managed => "false", :name => "Iteration")
    assert_equal TextPropertyDefinition, property_definition.class
    assert_equal "numeric", property_definition.property_type.to_s
  end
  
  def test_build_unmanaged_text_property_definitions
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "string", :is_managed => "false", :name => "Iteration")
    assert_equal TextPropertyDefinition, property_definition.class
    assert_equal "string", property_definition.property_type.to_s
  end
  
  def test_build_numeric_formula_property_definition
    property_definition = ApiPropertyDefinition.create(@project, :name => "some formula", :data_type => 'formula', :formula => '1 + 1')
    assert_equal FormulaPropertyDefinition, property_definition.class
    assert_equal "numeric", property_definition.property_type.to_s
  end

  def test_build_date_formula_property_definition
    setup_date_property_definition('date_prop')
    property_definition = ApiPropertyDefinition.create(@project, :name => "some formula", :data_type => 'formula', :formula => 'date_prop + 2')
    assert_equal FormulaPropertyDefinition, property_definition.class
    assert_equal "date", property_definition.property_type.to_s
  end

  def test_build_date_formula_property_definition_with_nonexist_date_property_name
    setup_date_property_definition('date_prop')
    assert_no_difference "PropertyDefinition.count" do
      property_definition = ApiPropertyDefinition.create(@project, :name => "some formula", :data_type => 'formula', :formula => 'date_sfdsafsdfasfd')
      assert property_definition.errors.any?
    end
  end

  def test_build_date_property_definition
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "date", :name => "Birthdays!")
    assert_equal DatePropertyDefinition, property_definition.class
    assert_equal "date", property_definition.property_type.to_s
  end

  def test_build_card_property_definition
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "card", :name => "Nascar glasses")
    assert_equal CardRelationshipPropertyDefinition, property_definition.class
    assert_equal "card", property_definition.property_type.to_s
  end

  def test_should_ignore_the_hidden_and_restricted_params
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "card", :name => "Nascar glasses", :hidden => true, :restricted => true, :transition_only => true)
    assert_equal false, property_definition.hidden?
    assert_equal false, property_definition.restricted?
    assert_equal false, property_definition.transition_only?
  end
  
  def test_providing_a_non_existent_card_type_will_result_in_error
    assert_no_difference "PropertyDefinition.count" do
      property_definition = ApiPropertyDefinition.create(@project, :data_type => "card", :name => "Nascar glasses", :card_types => [{ :name => 'I do not exist' }])
      assert_equal ["There is no such card type: I do not exist"], property_definition.errors.full_messages
    end
  end

  def test_providing_a_non_existent_data_type_will_result_in_error
    assert_no_difference "PropertyDefinition.count" do
      property_definition = ApiPropertyDefinition.create(@project, :data_type => "nascar", :name => "Nascar glasses")
      assert_equal ["There is no such data type: nascar"], property_definition.errors.full_messages
    end
  end
  
  def test_can_provide_data_type_and_is_managed_attributes_in_any_casing
    property_definition = ApiPropertyDefinition.create(@project, :data_type => "stRiNg", :is_managed => "TRue", :name => "Status")
    assert_equal EnumeratedPropertyDefinition, property_definition.class
    assert_equal "string", property_definition.property_type.to_s
  end
end
