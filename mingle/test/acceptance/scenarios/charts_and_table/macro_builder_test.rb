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

# Tags: chart
class MacroBuilderTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  TEAM_MEMBER_PROPERTY = 'user'
  SIZE = 'size'
  STATUS = 'status'
  ITERATION = 'iteration'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    @browser = selenium_session
    @project = create_project(:prefix => 'macro_builder_test', :users => [@project_member, users(:longbob)], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    login_as_admin_user
    open_project(@project)
  end

  def test_free_hand_macro
    add_card_with_detail_via_quick_add("card1")
    create_free_hand_macro("project")
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, @project.identifier)
    save_card
    open_card(@project, @project.cards.find_by_name("card1"))
    wait_for_card_contents_to_load
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, @project.identifier)
  end

  def test_error_message_for_invalid_macro
    add_card_with_detail_via_quick_add("card1")
    wait_for_wysiwyg_editor_ready
    enter_text_in_macro_editor("foo")
    click_ok_on_macro_editor
    verify_error_message_on_wysiwyg_editor("No such macro: foo Help")
  end

  
  def test_insert_project_macro
    add_card_with_detail_via_quick_add("card1")
    wait_for_wysiwyg_editor_ready
    insert_project_macro_and_save
    open_card(@project, @project.cards.find_by_name("card1"))
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, @project.identifier)
  end

    def test_insert_project_variable
    team_plv_name = 'team plv'
    team_plv_id = @project_member
    team_plv_full_value = "member@email.com (member)"

    team_property = create_team_property(TEAM_MEMBER_PROPERTY)
    create_user_plv(@project, team_plv_name, team_plv_id, [team_property])
    add_card_with_detail_via_quick_add("card1")
    open_project_variable_macro_editor_and_type_plv(team_plv_name)
    click_preview
    @browser.assert_text_present_in('macro_preview', team_plv_full_value)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, team_plv_full_value)
    save_card
    open_card(@project, @project.cards.find_by_name("card1"))
    wait_for_card_contents_to_load
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, team_plv_full_value)
  end

  
  def test_insert_average_value_query
    setup_numeric_property_definition(SIZE, [1, 2, 3, 4])
    create_card!(:name => 'card 1', SIZE => '2')
    create_card!(:name => 'card 2', SIZE => '4')
    add_card_with_detail_via_quick_add("card 3")
    insert_average_query("SELECT #{SIZE}")
    save_card
    open_card(@project, @project.cards.find_by_name("card 3"))
    wait_for_card_contents_to_load
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, '3')

    add_card_with_detail_via_quick_add('card 4')
    insert_value_query("SELECT SUM(#{SIZE})")
    save_card
    open_card(@project, @project.cards.find_by_name("card 4"))
    wait_for_card_contents_to_load
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS, '6')
  end

    def test_table_query
    add_card_with_detail_via_quick_add("card")
    insert_table_query("SELECT number,name")
    open_card(@project, @project.cards.find_by_name('card'))
    @browser.assert_element_present(table_present_in_wysiwyg_editor)
    assert_table_column_headers_and_order(CardEditPageId::RENDERABLE_CONTENTS, 'Number','Name')
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 1, :cell_values => ['1','card'])
  end

  def test_table_view_query
    create_cards(@project, 4)
    navigate_to_a_card_view('list')
    view_name = create_card_list_view_for(@project, 'my view')
    add_card_with_detail_via_quick_add("card 5")
    insert_table_view_macro_and_save(view_name.name)
    open_card(@project, @project.cards.find_by_name('card 5'))
    @browser.assert_element_present(table_present_in_wysiwyg_editor)
    assert_table_column_headers_and_order(CardEditPageId::RENDERABLE_CONTENTS, 'Number','Name')
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 1, :cell_values => ['5','card 5'])
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 2, :cell_values => ['4','card 4'])
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 3, :cell_values => ['3','card 3'])
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 4, :cell_values => ['2','card 2'])
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 5, :cell_values => ['1','card 1'])
  end

  def test_pivot_table
    setup_property_definitions(STATUS  => ['open','closed'], SIZE => [2, 4])
    create_card!(:name => 'card 1', SIZE => '2', STATUS => 'open')
    create_card!(:name => 'card 2',STATUS => 'closed',  SIZE => '4')
    create_card_for_edit(@project, "card 3", :wait => true)
    insert_pivot_table_macro(STATUS, SIZE)
    @browser.assert_element_present(table_present_in_wysiwyg_editor)
    assert_table_column_headers_and_order(CardEditPageId::RENDERABLE_CONTENTS, "",'open', 'closed', '(not set)')
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 1, :cell_values => [1,'',''])
    assert_table_row_data_for(CardEditPageId::RENDERABLE_CONTENTS, :row_number => 2, :cell_values => ['',1,''])
  end
  
end
