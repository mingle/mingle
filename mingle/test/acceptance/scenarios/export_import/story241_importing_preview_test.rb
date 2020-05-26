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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: story, #241, import-export, cards, tagging
class Story241ImportingPreviewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  AS_CARD_DESCRIPTION = 'as card description'
  AS_CARD_NAME = 'as card name'
  AS_CARD_NUMBER = 'as card number'
  AS_CARD_TYPE = 'as card type'
  AS_INCOMPLETE_CHECKLIST_ITEMS='as incomplete checklist items'
  AS_COMPLETED_CHECKLIST_ITEMS='as completed checklist items'
  IGNORE = 'ignore'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'story241', :admins => [users(:project_member)])
    login_as_project_member

    header_row = ['Ticket', 'Note', 'Summary','Size','Incomplete Checklist Items', 'Completed Checklist Items']
    card_data = [
        ['1', 'authorization', 'Enters account name and password', '2', "\"get account name\rget password\"", 'make form'],
        ['2', 'communication', 'Add a new RSS URL', '4',"\"parse url\rget content\"",''],
        ['3', 'validation', 'Incorrectly Updated', '2','','validate']]
    navigate_to_card_list_for(@project)
    @browser.assert_text_present "There are no cards for #{@project.name}"
    @browser.click 'link=import existing cards'
    @browser.wait_for_element_visible 'tab_separated_import'
    @browser.type 'tab_separated_import', excel_copy_string(header_row, card_data)
    submit_to_preview
  end

  def test_preview_should_have_same_data_as_import
    preview = HtmlTable.new(@browser, 'preview_table', ['Ticket', 'Note', 'Size', 'Incomplete Checklist Items', 'Completed Checklist Items'], 1, 0)
    preview.assert_row_values(1, ['', '1', 'authorization','Enters account name and password', '2',"get account name\nget password", 'make form'])
    preview.assert_row_values(2, ['', '2', 'communication', 'Add a new RSS URL', '4',"parse url\nget content",''])
    preview.assert_row_values(3, ['', '3', 'validation', 'Incorrectly Updated', '2','','validate'])

    @browser.assert_selected_label 'ticket_import_as', AS_CARD_NUMBER
    @browser.assert_selected_label 'note_import_as', "as new #{CardImport::Mappings::TEXT_LIST_PROPERTY}"
    @browser.assert_selected_label 'summary_import_as', AS_CARD_NAME
    @browser.assert_selected_label 'size_import_as', "as new #{CardImport::Mappings::NUMERIC_LIST_PROPERTY}"

    import_from_preview(:map => {'note' => AS_CARD_NAME, 'summary' => AS_CARD_DESCRIPTION,
                                 'incomplete checklist items'=> AS_INCOMPLETE_CHECKLIST_ITEMS,
                                 'completed checklist items' => AS_COMPLETED_CHECKLIST_ITEMS})

    @browser.assert_location "/projects/#{@project.identifier}/cards/list?style=list&tab=All"

    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    cards.assert_row_values(1, ['3', 'validation'])
    cards.assert_row_values(2, ['2', 'communication'])
    cards.assert_row_values(3, ['1', 'authorization'])
  end

  def test_setting_two_columns_as_name_number_or_description_causes_a_validation_error
    import_from_preview(:map => {'note' => AS_CARD_NAME, 'summary' => AS_CARD_NAME})
    @browser.assert_text_present 'Multiple columns are marked as card name.'
  end

  def test_should_assign_names_when_importing_cards_without_names
    import_from_preview(:map => {'summary' => AS_CARD_DESCRIPTION})

    @browser.assert_location "/projects/#{@project.identifier}/cards/list?style=list&tab=All"

    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    cards.assert_row_values(1, ['3', 'Card 3'])
    cards.assert_row_values(2, ['2', 'Card 2'])
    cards.assert_row_values(3, ['1', 'Card 1'])
  end

  def test_ignoring_rows_should_cause_them_not_to_get_imported
    import_from_preview(:ignores => [1, 2])
    @browser.assert_location "/projects/#{@project.identifier}/cards/list?style=list&tab=All"

    @browser.assert_text_present "Importing complete, 1 row, 0 updated, 1 created, 0 errors."
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    cards.assert_row_values(1, ['3', 'Incorrectly Updated'])
  end
end
