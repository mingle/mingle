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


class PropertyDataExporterTest < ActiveSupport::TestCase
  def test_should_export_to_sheet_and_name
    assert PropertyDataExporter.new('').exports_to_sheet?
    assert_equal 'Properties', PropertyDataExporter.new('').name
  end

  def test_sheet_should_contain_correct_property_data
    login_as_admin
    with_new_project do |project|
      status_prop_def = project.create_any_text_definition!(:name => 'status', :type => 'any text', :description => 'It is a manage text property')
      estimate_prop_def = project.create_text_list_definition!(:name => 'estimate', :type => 'number list', :description => 'It is a number list property', :hidden => true)

      property_data_exporter = PropertyDataExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(property_data_exporter.name)
      property_data_exporter.export(sheet)

      assert_equal 8, sheet.headings.count
      assert_equal project.property_definitions_in_smart_order(true).count + 1, sheet.number_of_rows
      assert_equal ['Name', 'Description', 'Type', 'Values', 'Hidden', 'Locked', 'Transition only', 'Data exceeding 32767 character limit'], sheet.headings
      assert_equal [estimate_prop_def.name, estimate_prop_def.description, estimate_prop_def.describe_type, property_definition_value(estimate_prop_def), boolean_property_definition(estimate_prop_def.hidden), boolean_property_definition(estimate_prop_def.restricted), boolean_property_definition(estimate_prop_def.transition_only)], sheet.row(1)
      assert_equal [status_prop_def.name, status_prop_def.description, status_prop_def.describe_type, property_definition_value(status_prop_def), boolean_property_definition(status_prop_def.hidden), boolean_property_definition(status_prop_def.restricted), boolean_property_definition(status_prop_def.transition_only)], sheet.row(2)
    end
  end

  def test_sheet_should_contain_correct_property_type_for_tree_and_user_property_definitions
    login_as_admin
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Tree')
      type_story = project.card_types.create :name => 'story'
      type_release = project.card_types.create :name => 'release'
      tree_config.update_card_types({
                                        type_release => {:position => 0, :relationship_name => 'release'},
                                        type_story => {:position => 1}
                                    })
      tree_prop_def = tree_config.relationships.first
      user_prop_def = project.create_user_definition!(:name => 'Owner', :description => 'it is an user property')

      property_data_exporter = PropertyDataExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(property_data_exporter.name)
      property_data_exporter.export(sheet)

      assert_equal [user_prop_def.name, user_prop_def.description, 'User', user_prop_def.property_values_description, boolean_property_definition(user_prop_def.hidden), boolean_property_definition(user_prop_def.restricted), boolean_property_definition(user_prop_def.transition_only)], sheet.row(1)
      assert_equal [tree_prop_def.name, tree_prop_def.description || '', 'Tree Relationship', tree_prop_def.property_values_description, boolean_property_definition(tree_prop_def.hidden), boolean_property_definition(tree_prop_def.restricted), boolean_property_definition(tree_prop_def.transition_only)], sheet.row(2)
    end
  end

  def test_sheet_should_contain_correct_value_for_formula_and_aggregate_property_definitions
    login_as_admin
    with_new_project do |project|
      estimate_prop_def = project.create_text_list_definition!(:name => 'estimate', :type => 'number list', :description => 'It is a number list property', :hidden => true, :is_numeric => true)
      type_story = project.card_types.create :name => 'story'
      type_story.add_property_definition estimate_prop_def
      type_story.save!
      type_release = project.card_types.create :name => 'release'
      tree_config = project.tree_configurations.create!(:name => 'Tree')
      tree_config.update_card_types({
                                        type_release => {:position => 0, :relationship_name => 'release'},
                                        type_story => {:position => 1}
                                    })
      aggregate_property_options = {
          :name => 'aggregate prop def',
          :description => 'it is a aggregate property',
          :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
          :aggregate_type => AggregateType::AVG,
          :aggregate_card_type_id => type_release.id, :tree_configuration_id => tree_config.id}
      aggregate_property_options.merge!(:aggregate_target_id => estimate_prop_def.id)


      formula_prop_def = project.create_formula_property_definition!(:name => 'formula', :description => 'it is a formula property', :formula => '5 * 4')
      aggregate_prop_def = project.create_aggregate_property_definition!(aggregate_property_options)

      property_data_exporter = PropertyDataExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(property_data_exporter.name)
      property_data_exporter.export(sheet)

      assert_equal [aggregate_prop_def.name, aggregate_prop_def.description, aggregate_prop_def.describe_type, 'Average of estimate', boolean_property_definition(aggregate_prop_def.hidden), boolean_property_definition(aggregate_prop_def.restricted), boolean_property_definition(aggregate_prop_def.transition_only)], sheet.row(1)
      assert_equal [formula_prop_def.name, formula_prop_def.description, formula_prop_def.describe_type, '(5 * 4)', boolean_property_definition(formula_prop_def.hidden), boolean_property_definition(formula_prop_def.restricted), boolean_property_definition(formula_prop_def.transition_only)], sheet.row(3)
    end
  end

  def test_should_be_exportable_when_property_definitions_are_defined
    login_as_admin
    with_new_project do |project|
      project.create_text_list_definition!(:name => 'estimate', :type => 'number list', :description => 'It is a number list property', :hidden => true, :is_numeric => true)

      property_data_exporter = PropertyDataExporter.new('')
      assert property_data_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_property_definitions_are_not_defined
    login_as_admin
    with_new_project do
      property_data_exporter = PropertyDataExporter.new('')
      assert_false property_data_exporter.exportable?
    end
  end

  def test_sheet_should_handle_large_property_values
    login_as_admin
    with_new_project do |project|
      status_prop_def = project.create_any_text_definition!(:name => 'status', :type => 'any text', :description => 'It is a manage text property')
      estimate_prop_def = project.create_text_list_definition!(:name => 'estimate', :type => 'number list', :description => 'It is a number list property', :hidden => true)
      200.times do | x |
        EnumerationValue.create!(property_definition_id: estimate_prop_def.id, value:  " value : #{x} #{"a" * 200}")
      end
      # estimate_prop_def.reload
      tmp_dir = RailsTmpDir::RailsTmpFileProxy.new('exports').pathname
      property_data_exporter = PropertyDataExporter.new(tmp_dir)
      large_descriptions_path = File.join(tmp_dir, 'Large descriptions')
      sheet = ExcelBook.new('test').create_sheet(property_data_exporter.name)
      property_data_exporter.export(sheet)
      large_prop_def_value_file = "property_definition_#{estimate_prop_def.name}_Values.txt"
      large_prop_def_value_abs_path = File.join(large_descriptions_path,large_prop_def_value_file)
      large_prop_def_value = "Content too large. Written to file:Large descriptions/#{large_prop_def_value_file}"


      assert(File.directory?(large_descriptions_path))
      assert(File.exists?(large_prop_def_value_abs_path))
      assert_equal(property_definition_value(estimate_prop_def), File.read(large_prop_def_value_abs_path))
      assert_equal 8, sheet.headings.count
      assert_equal project.property_definitions_in_smart_order(true).count + 1, sheet.number_of_rows

      assert_equal ['Name', 'Description', 'Type', 'Values', 'Hidden', 'Locked', 'Transition only', 'Data exceeding 32767 character limit'], sheet.headings
      assert_equal [estimate_prop_def.name, estimate_prop_def.description, estimate_prop_def.describe_type, large_prop_def_value, boolean_property_definition(estimate_prop_def.hidden), boolean_property_definition(estimate_prop_def.restricted), boolean_property_definition(estimate_prop_def.transition_only), 'Values'], sheet.row(1)
      assert_equal [status_prop_def.name, status_prop_def.description, status_prop_def.describe_type, property_definition_value(status_prop_def), boolean_property_definition(status_prop_def.hidden), boolean_property_definition(status_prop_def.restricted), boolean_property_definition(status_prop_def.transition_only)], sheet.row(2)
    end
  end

  private

  def property_definition_value(prop_def)
    prop_def.is_a?(EnumeratedPropertyDefinition) ? prop_def.label_values_for_charting.join("\n") : prop_def.property_values_description
  end

  def boolean_property_definition(prop_def_value)
    prop_def_value ? 'Yes' : 'No'
  end
end
