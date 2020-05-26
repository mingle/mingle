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

class CardDataExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    with_new_project do
      assert CardDataExporter.new('').exports_to_sheet?
      assert_equal 'Cards', CardDataExporter.new('').name
    end
  end

  def test_insert_correct_data_into_excel_sheet
    login_as_admin
    with_new_project do |project|
      release_type = project.card_types.create(name: 'Release')
      iteration_type = project.card_types.create(name: 'Iteration')
      story_type = project.card_types.create(name: 'Story')

      status_prop_def = project.create_text_list_definition!(name: 'Status')
      status_prop_def.card_types = [story_type, iteration_type, release_type]
      status_prop_def.save!
      hidden_prop_def = project.create_text_list_definition!(name: 'hidden_prop', hidden: true)
      hidden_prop_def.card_types = [release_type, iteration_type]
      hidden_prop_def.save!
      project.reload

      large_description = generate_random_string(36600)
      release_card = project.cards.create!(name: "Release 1", description: large_description, card_type: release_type, cp_status: 'status value 1', cp_hidden_prop: 'hidden_prop val 1')
      release_card.tag_with('Tag1')
      release_card.attach_files(sample_attachment, another_sample_attachment)

      iteration_card = project.cards.create!(name: "Iteration 1", description: "<div><strong>Iteration 1 </strong> content {{\n my-macro\n  a:b\n}} {{ daily-history-chart }} {{ my-macro }}</div>", card_type: iteration_type, cp_status: 'status value 1', cp_hidden_prop: 'hidden_prop val 1')
      iteration_card.tag_with('Tag1')
      iteration_card.attach_files(sample_attachment)
      story_card = project.cards.create!(name: "Story 1", description: "<div><strong>Story 1 </strong> content </div>", card_type: story_type, cp_status: 'status value 1')
      story_card.tag_with('Tag1')
      story_card.checklist_items.create({:text => "in completed checklist 1", :completed => false, :position => 0})
      story_card.checklist_items.create({:text => "in completed checklist 2", :completed => false, :position => 0})
      story_card.checklist_items.create({:text => "completed checklist 1", :completed => true, :position => 0})
      story_card.checklist_items.create({:text => "completed checklist 2", :completed => true, :position => 0})

      tmp_dir = RailsTmpDir::RailsTmpFileProxy.new('exports').pathname
      card_data_exporter = CardDataExporter.new(tmp_dir, export_id: Export.create.id)
      sheet = ExcelBook.new('test').create_sheet(card_data_exporter.name)
      card_data_exporter.export(sheet)

      large_descriptions_path = File.join(tmp_dir, 'Large descriptions')
      assert(File.directory?(large_descriptions_path))
      plain_text_large_content_file = File.join(large_descriptions_path, "card_#{release_card.number}_Description (Plain text).txt")
      html_large_content_file = File.join(large_descriptions_path, "card_#{release_card.number}_Description (HTML).txt")

      assert(File.exists?(plain_text_large_content_file))
      assert(File.exists?(html_large_content_file))
      assert_equal(large_description, File.read(plain_text_large_content_file))
      assert_equal(large_description, File.read(html_large_content_file))

      assert_equal 16, sheet.headings.count
      assert_equal 4, sheet.number_of_rows
      assert_equal ['Number', 'Name', 'Description (Plain text)', 'Description (HTML)', 'Type', 'hidden_prop(Hidden)', 'Status', 'Created by', 'Modified by', 'Tags', 'Incomplete checklist items', 'Complete checklist items', 'Attachments', 'Has charts', 'Charts and macros', 'Data exceeding 32767 character limit'], sheet.headings
      assert_equal sheet.row(0), sheet.headings
      assert_equal card_data(release_card, [hidden_prop_def, status_prop_def], true), sheet.row(1)
      iteration_card_macros = ['2 My macros', '1 Daily history chart']
      assert_equal card_data(iteration_card, [hidden_prop_def, status_prop_def], false, 'Y', iteration_card_macros), sheet.row(2)
      assert_equal card_data(story_card, [hidden_prop_def, status_prop_def]), sheet.row(3)

      assert_equal "#{MingleConfiguration.site_url}/projects/#{project.identifier}/cards/#{release_card.number}", sheet.cell_link_address(1,1)
      assert_equal "#{MingleConfiguration.site_url}/projects/#{project.identifier}/cards/#{iteration_card.number}", sheet.cell_link_address(2,1)
      assert_equal "#{MingleConfiguration.site_url}/projects/#{project.identifier}/cards/#{story_card.number}", sheet.cell_link_address(3,1)

    end
  end

  def test_should_be_exportable_when_project_has_cards
    login_as_admin
    with_new_project do |project|
      story_type = project.card_types.create(name: 'Story')
      project.cards.create!(name: "Story 1", description: "<div><strong>Release 1 </strong> content </div>", card_type: story_type)
      card_data_exporter = CardDataExporter.new(RailsTmpDir::RailsTmpFileProxy.new('exports').pathname, export_id: Export.create.id)
      assert card_data_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_there_are_no_cards
    login_as_admin
    with_new_project do |project|
      card_data_exporter = CardDataExporter.new(RailsTmpDir::RailsTmpFileProxy.new('exports').pathname, export_id: Export.create.id)
      assert_false card_data_exporter.exportable?
    end
  end

  private
  def card_data(card, project_property_definitions, file_export=false, has_macros='N', macros=[])
    description = card.description
    plain_text_description = description ? Nokogiri.HTML(card.description).text : ''
    if file_export
      plain_text_description = "Content too large. Written to file:Large descriptions/card_#{card.number}_Description (Plain text).txt"
      description = "Content too large. Written to file:Large descriptions/card_#{card.number}_Description (HTML).txt"
    end
    property_definitions_for_card = project_property_definitions.map do |property_definition|
      property_definition.property_value_on(card).export_value || ''
    end
    rows = [
        card.number, card.name, plain_text_description,
        description, card.card_type.name, property_definitions_for_card,
        card.created_by.login, card.modified_by.login, card.tags.join(","), card.incomplete_checklist_items.map(&:text).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR),
        card.completed_checklist_items.map(&:text).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR),
        card.reload.attachments.map {|a| "Attachments/#{card.prefixed_number}/#{a.file_name}"}.join(CardExport::LIST_ITEM_EXPORT_SEPARATOR),
        has_macros, macros.join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)
    ].flatten
    rows << "Description (Plain text)\rDescription (HTML)" if file_export
    rows
  end
end
