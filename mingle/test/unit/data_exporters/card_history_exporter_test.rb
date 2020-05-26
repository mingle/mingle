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

class CardHistoryExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    card_history_exporter = CardHistoryExporter.new('')
    assert card_history_exporter.exports_to_sheet?
    assert_equal 'Card history', card_history_exporter.name
  end

  def test_insert_correct_data_into_excel_sheet
    login_as_admin
    with_new_project(time_zone: 'London', date_format: '%m/%d/%Y') do |project|
      time = DateTime.now.yesterday
      card = nil
      new_large_desc = generate_random_string(37500)
      Timecop.travel(time) do
        release_type = project.card_types.create(name: 'Release')
        story_type = project.card_types.create(name: 'Story')

        status_prop_def = project.create_text_list_definition!(name: 'Status')
        status_prop_def.card_types = [story_type, release_type]
        status_prop_def.save!

        project.reload
        Timecop.travel(time + 1.minute) do
          card = project.cards.create!(name: "Story 1", card_type: story_type, cp_status: 'new')
        end
        Timecop.travel(time + 2.minute) do
          card.tag_with('Tag1')
          card.save!
        end
        Timecop.travel(time + 3.minute) do
          card.attach_files(sample_attachment('attachment.png'))
          card.save!
          end
        Timecop.travel(time + 4.minute) do
          card.remove_tag('Tag1')
          card.save!
        end
        Timecop.travel(time + 5.minute) do
          card.update_attribute(:cp_status, 'in todo')
          card.save!
        end
        Timecop.travel(time + 6.minute) do
          card.card_type = release_type
          card.save!
        end
        Timecop.travel(time + 7.minute) do
          card.description = new_large_desc
          card.save!
        end
      end
      generate_changes_for_versions(card.versions)
      with_temp_dir do |tmp|
        card_data_exporter = CardHistoryExporter.new(tmp, export_id: Export.create.id)
        sheet = ExcelBook.new('test').create_sheet(card_data_exporter.name)
        card_data_exporter.export(sheet)
        change_id = card.versions.find_by_version(7).changes.first.id

        assert_equal 14, sheet.headings.count
        assert_equal 11, sheet.number_of_rows
        assert_equal ['Date', 'Time', 'Modified by', 'Card', 'Card type', 'Event', 'Property', 'From', 'To', 'Description changes', 'Tag', 'Attachment name', 'Murmur', 'Data exceeding 32767 character limit'], sheet.headings
        assert_equal sheet.row(0), sheet.headings


        assert(File.directory?(File.join(tmp, 'Large descriptions')))
        assert_equal("--- \n+++ \n@@ -1,1 +1,1 @@\n-\n+#{new_large_desc}", File.read(File.join(tmp, 'Large descriptions', "card_history_1_7_#{change_id}_Description changes.txt")))

        row_1 = [project.format_date(time), project.format_time_without_date(time + 7.minute), 'admin', "##{card.number}", 'Release', 'Description changed', '', '', '', "Content too large. Written to file:Large descriptions/card_history_1_7_#{change_id}_Description changes.txt", '', '', '', 'Description changes']
        row_2 = [project.format_date(time), project.format_time_without_date(time + 6.minute), 'admin', "##{card.number}", 'Release', 'Card type changed', '', 'Story', 'Release', '', '', '', '']
        row_3 = [project.format_date(time), project.format_time_without_date(time + 5.minute), 'admin', "##{card.number}", 'Story', 'Property changed', 'Status', 'new', 'in todo', '', '', '', '']
        row_4 = [project.format_date(time), project.format_time_without_date(time + 4.minute), 'admin', "##{card.number}", 'Story', 'Tag removed', '', '', '','' ,'Tag1', '', '']
        row_5 = [project.format_date(time), project.format_time_without_date(time + 3.minute), 'admin', "##{card.number}", 'Story', 'Attachment added', '', '', '','', '', 'attachment.png', '']
        row_6 = [project.format_date(time), project.format_time_without_date(time + 2.minute), 'admin', "##{card.number}", 'Story', 'Tag added', '', '', '','', 'Tag1', '', '']
        row_7 = [project.format_date(time), project.format_time_without_date(time + 1.minute), 'admin', "##{card.number}", 'Story', 'Name set', '', '', 'Story 1', '', '', '', '']
        row_8 = [project.format_date(time), project.format_time_without_date(time + 1.minute), 'admin', "##{card.number}", 'Story', 'Card type set', '', '', 'Story', '', '', '', '']
        row_9 = [project.format_date(time), project.format_time_without_date(time + 1.minute), 'admin', "##{card.number}", 'Story', 'Property set', 'Status', '', 'new','','', '', '']
        row_10 = [project.format_date(time), project.format_time_without_date(time + 1.minute), 'admin', "##{card.number}", 'Story', 'Card created', '', '', '','', '', '', '']

        assert_equal row_1, sheet.row(1)
        assert_equal row_2, sheet.row(2)
        assert_equal row_3, sheet.row(3)
        assert_equal row_4, sheet.row(4)
        assert_equal row_5, sheet.row(5)
        assert_equal row_6, sheet.row(6)
        assert_equal row_7, sheet.row(7)
        assert_equal row_8, sheet.row(8)
        assert_equal row_9, sheet.row(9)
        assert_equal row_10, sheet.row(10)
      end
    end
  end

  def test_should_be_exportable_when_card_history_is_present
    login_as_admin
    with_new_project(time_zone: 'London', date_format: '%m/%d/%Y') do |project|
      time = DateTime.now.yesterday
      card = nil
      Timecop.travel(time) do
        release_type = project.card_types.create(name: 'Release')
        story_type = project.card_types.create(name: 'Story')

        status_prop_def = project.create_text_list_definition!(name: 'Status')
        status_prop_def.card_types = [story_type, release_type]
        status_prop_def.save!
        project.reload
        Timecop.travel(time + 1.minute) do
          card = project.cards.create!(name: "Story 1", card_type: story_type, cp_status: 'new')
        end
        Timecop.travel(time + 2.minute) do
          card.tag_with('Tag1')
          card.save!
        end
      end
      generate_changes_for_versions(card.versions)
      card_data_exporter = CardHistoryExporter.new('',export_id: Export.create.id)
      assert card_data_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_there_is_no_card_history
    login_as_admin
    with_new_project(name: 'Random project',time_zone: 'London', date_format: '%m/%d/%Y') do |project|
      time = DateTime.now.yesterday
      first_page = nil
      Timecop.travel(time) do
        Timecop.travel(time + 1.minute) do
          first_page = project.pages.create!(:name => 'First page')
        end
        Timecop.travel(time + 2.minute) do
          first_page.tag_with('Tag 1')
          first_page.save!
        end
      end
      generate_changes_for_versions(first_page.versions)
      card_data_exporter = CardHistoryExporter.new('',export_id: Export.create.id)
      assert_false card_data_exporter.exportable?

    end
  end

  private

  def generate_changes_for_versions(versions)
    versions.each do |version|
      version.event.send(:generate_changes)
    end
  end


end
