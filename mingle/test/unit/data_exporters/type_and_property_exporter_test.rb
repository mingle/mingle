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

class TypeAndPropertyExporterTest < ActiveSupport::TestCase
  def test_should_export_to_sheet_and_name
    assert TypeAndPropertyExporter.new('').exports_to_sheet?
    assert_equal 'Types and Properties', TypeAndPropertyExporter.new('').name
  end

  def test_sheet_should_contain_correct_card_type_and_property_data
    login_as_admin
    with_new_project do |project|
      card_type = project.card_types.create(name: 'Story')
      card_defaults = card_type.card_defaults

      status_prop_def = project.create_any_text_definition!(:name => 'status', :type => 'any text', :description => 'It is a manage text property')
      estimate_prop_def = project.create_text_list_definition!(:name => 'estimate', :type => 'number list', :description => 'It is a number list property', :hidden => true)
      formula_prop_def = project.create_formula_property_definition!(:name => 'formula', :formula => '2 * 2')

      card_type.add_property_definition status_prop_def
      card_type.add_property_definition estimate_prop_def
      card_type.add_property_definition formula_prop_def
      card_type.save!

      card_defaults.update_properties :status => 'done'
      card_defaults.update_properties :estimate => '1'
      card_defaults.save!

      type_and_property_data_exporter = TypeAndPropertyExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(type_and_property_data_exporter.name)
      type_and_property_data_exporter.export(sheet)

      assert_equal 3, sheet.headings.count
      assert_equal card_type.property_definitions_with_hidden_in_smart_order.count + 1, sheet.number_of_rows
      assert_equal ['Card Type', 'Property', 'Default value'], sheet.headings
      assert_equal [card_type.name, estimate_prop_def.name, 1], sheet.row(1)
      assert_equal [card_type.name, formula_prop_def.name, '(calculated)'], sheet.row(2)
      assert_equal [card_type.name, status_prop_def.name, 'done'], sheet.row(3)
    end
  end

  def test_should_be_exportable_when_card_types_are_defined
    login_as_admin
    with_new_project do |project|
      card_type = project.card_types.create(name: 'Story')
      status_prop_def = project.create_any_text_definition!(:name => 'status', :type => 'any text', :description => 'It is a manage text property')
      card_type.add_property_definition status_prop_def
      type_and_property_data_exporter = TypeAndPropertyExporter.new('')

      assert type_and_property_data_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_card_types_are_not_defined
    login_as_admin
    with_new_project do
      type_and_property_data_exporter = TypeAndPropertyExporter.new('')

      assert_false type_and_property_data_exporter.exportable?
    end
  end
end
