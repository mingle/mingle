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

class CardTypeExporterTest <  ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    assert CardTypeExporter.new('').exports_to_sheet?
    assert_equal 'Card types', CardTypeExporter.new('').name
  end

  def test_sheet_should_contain_correct_CardTypes_data
    with_new_project do |project|
      card_type = project.card_types.create(name: 'Story')
      card_defaults = card_type.card_defaults
      card_defaults.description = '<p>something</p>'
      card_defaults.save!

      card_type_exporter = CardTypeExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(card_type_exporter.name)
      card_type_exporter.export(sheet)

      assert_equal 3, sheet.headings.count
      assert_equal project.card_types.count + 1, sheet.number_of_rows
      assert_equal ['Card types', 'Default Description(Plain text)', 'Default Description(HTML)'], sheet.headings
      assert_equal [card_type.name,'something',card_type.card_defaults.description], sheet.row(2)
    end
  end

  def test_should_be_exportable_when_project_have_card_types
    login_as_admin
    with_new_project do |project|
      project.card_types.create(name: 'Story')
      card_type_exporter = CardTypeExporter.new('')
      assert card_type_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_project_does_not_have_card_types
    login_as_admin
    with_new_project do |project|
      project.card_types.destroy_all
      card_type_exporter = CardTypeExporter.new('')
      assert_false card_type_exporter.exportable?
    end
  end

end
