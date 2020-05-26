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

class ProjectVariableExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    assert ProjectVariableExporter.new('').exports_to_sheet?
    assert_equal 'Project variables', ProjectVariableExporter.new('').name
  end

  def test_sheet_should_contain_correct_project_variable_data
    login_as_admin
    with_new_project do |project|
      test_prop_def = setup_managed_text_definition('Test', %w(new done))
      card_type = project.card_types.create(name: 'Story')
      card = project.cards.create(:name => 'Stroy 1', :card_type => card_type)
      card_type_plv = project.project_variables.create!(:name => 'CardTypePV', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => card.id, :card_type => card_type)
      string_type_plv = project.project_variables.create!(:name => 'StringTypePV', :data_type => ProjectVariable::STRING_DATA_TYPE, value: '22-10-2018', :property_definitions => [test_prop_def])

      project_variable_exporter = ProjectVariableExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(project_variable_exporter.name)
      project_variable_exporter.export(sheet)

      assert_equal 4, sheet.headings.count
      assert_equal ProjectVariable.all.count + 1, sheet.number_of_rows
      assert_equal ['Name', 'Type', 'Properties', 'Value'], sheet.headings
      assert_equal [card_type_plv.name, card_type_plv.data_type_description, card_type_plv.property_definition_names.join(','), card_type_plv.export_value], sheet.row(1)
      assert_equal [string_type_plv.name, string_type_plv.data_type_description, string_type_plv.property_definition_names.join(','), string_type_plv.export_value], sheet.row(2)
    end
  end

  def test_should_be_exportable_when_project_have_plvs
    login_as_admin
    with_new_project do |project|
      test_prop_def = setup_managed_text_definition('Test', %w(new done))
      project.project_variables.create!(:name => 'StringTypePV', :data_type => ProjectVariable::STRING_DATA_TYPE, value: '22-10-2018', :property_definitions => [test_prop_def])
      project_variable_exporter = ProjectVariableExporter.new('')

      assert project_variable_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_project_does_not_have_plvs
    login_as_admin
    with_new_project do
      project_variable_exporter = ProjectVariableExporter.new('')

      assert_false project_variable_exporter.exportable?
    end
  end
end
