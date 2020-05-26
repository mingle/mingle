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

# Tags: properties
class Scenario51ProtectedPropertiesTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  DEFECT = 'defect'
  STORY = 'story'

  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'

  ITERATION = 'iteration'
  STATUS = 'Status'
  NEW = 'new'
  OPEN = 'open'
  CLOSED = 'CLOSED'

  VALID_DATE = '06 Oct 2015'
  ANOTHER_VALID_DATE = '10 Apr 1980'
  TEXT = 'this is incredible'
  DIFFERENT_TEXT = 'foo foo foo'
  ADMIN_NAME_TRUNCATED = "admin@emai..."


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_51', :users => [@mingle_admin, @team_member], :admins => [@project_admin])
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], ITERATION => [1, 2])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    setup_card_type(@project, DEFECT, :properties => [STATUS])
    setup_card_type(@project, STORY, :properties => [STATUS, ITERATION, USER_PROPERTY, FREE_TEXT_PROPERTY, DATE_PROPERTY])
    login_as_admin_user
    @story_one = create_card!(:name => 'story one', :type => STORY)
    @story_two = create_card!(:name => 'story two')
    @story_three = create_card!(:name => 'story three')
  end

  def teardown
    @project.deactivate
  end

  def test_only_project_and_mingle_admins_can_make_properties_protected
    navigate_to_property_management_page_for(@project)
    assert_transition_only_check_box_enabled(@project, STATUS)
    make_property_transition_only_for(@project, STATUS)
    assert_notice_message("Property #{STATUS} can now only be changed through a transition.")
    logout

    login_as(@project_admin.login)
    navigate_to_property_management_page_for(@project)
    make_property_transition_only_for(@project, ITERATION)
    assert_notice_message("Property #{ITERATION} can now only be changed through a transition.")
    logout

    login_as_team_member
    navigate_to_property_management_page_for(@project)
    assert_transition_only_check_box_disabled(@project, STATUS)
  end

  def test_project_and_mingle_admins_can_update_values_of_protected_properties_on_card_show_and_edit
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)

    open_card(@project, @story_one.number)
    set_properties_on_card_show(ITERATION => '2')
    set_properties_on_card_show(USER_PROPERTY => @team_member.name)
    add_new_value_to_property_on_card_show(@project, DATE_PROPERTY, VALID_DATE)
    add_new_value_to_property_on_card_show(@project, FREE_TEXT_PROPERTY, TEXT)

    @browser.wait_for_all_ajax_finished
    assert_history_for(:card, @story_one.number).version(2).shows(:set_properties => {ITERATION => '2'})
    assert_history_for(:card, @story_one.number).version(3).shows(:set_properties => {USER_PROPERTY => @team_member.name})
    assert_history_for(:card, @story_one.number).version(4).shows(:set_properties => {DATE_PROPERTY => VALID_DATE})
    assert_history_for(:card, @story_one.number).version(5).shows(:set_properties => {FREE_TEXT_PROPERTY => TEXT})

    #bug 2488
    open_card_for_edit(@project, @story_one.number)
    set_properties_in_card_edit(ITERATION => '1')
    set_properties_in_card_edit(USER_PROPERTY => @project_admin.name)
    add_new_value_to_property_on_card_edit(@project, DATE_PROPERTY, ANOTHER_VALID_DATE)
    add_new_value_to_property_on_card_edit(@project, FREE_TEXT_PROPERTY, DIFFERENT_TEXT)
    save_card
    assert_history_for(:card, @story_one.number).version(6).shows(:changed => ITERATION, :from => 2, :to => 1)
    assert_history_for(:card, @story_one.number).version(6).shows(:changed => USER_PROPERTY, :from => @team_member.name, :to => @project_admin.name)
    assert_history_for(:card, @story_one.number).version(6).shows(:changed => DATE_PROPERTY, :from => VALID_DATE, :to => ANOTHER_VALID_DATE)
    assert_history_for(:card, @story_one.number).version(6).shows(:changed => FREE_TEXT_PROPERTY, :from => TEXT, :to => DIFFERENT_TEXT)
  end

  def test_project_and_mingle_admins_can_update_values_of_transition_only_properties_via_excel_import
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)
    warnings = ["Property #{ITERATION} is transition only and will be ignored when updating cards. When creating new cards, these values will be set.",
                "Property #{USER_PROPERTY} is transition only and will be ignored when updating cards. When creating new cards, these values will be set.",
                "Property #{DATE_PROPERTY} is transition only and will be ignored when updating cards. When creating new cards, these values will be set.",
                "Property #{FREE_TEXT_PROPERTY} is transition only and will be ignored when updating cards. When creating new cards, these values will be set."]

    navigate_to_card_list_for(@project)
    header_row = ['name', 'type', 'number', ITERATION, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY]
    card_data = [[@story_two.name, @story_two.class.name, @story_two.number, '1', "#{@project_admin.login}", ANOTHER_VALID_DATE, DIFFERENT_TEXT]]
    preview(excel_copy_string(header_row, card_data))
    assert_warning_message(warnings.join)
    import_from_preview
    @browser.run_once_history_generation
    open_card(@project, @story_two.number)
    assert_properties_set_on_card_show(ITERATION => '1')
    assert_history_for(:card, @story_two.number).version(2).shows(:set_properties => {ITERATION => '1'})
    assert_history_for(:card, @story_two.number).version(2).shows(:set_properties => {USER_PROPERTY => @project_admin.login})
    assert_history_for(:card, @story_two.number).version(2).shows(:set_properties => {DATE_PROPERTY => ANOTHER_VALID_DATE})
    assert_history_for(:card, @story_two.number).version(2).shows(:set_properties => {FREE_TEXT_PROPERTY => DIFFERENT_TEXT})
  end

  def test_project_and_mingle_admins_can_update_values_of_protected_properties_via_bulk_edit
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)

    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    set_bulk_properties(@project, ITERATION => '2')
    set_bulk_properties(@project, USER_PROPERTY => @mingle_admin.name)
    add_value_to_date_property_using_inline_editor_on_bulk_edit(DATE_PROPERTY, VALID_DATE)
    add_value_to_free_text_property_using_inline_editor_on_bulk_edit(FREE_TEXT_PROPERTY, TEXT)
    open_card(@project, @story_three.number)
    assert_history_for(:card, @story_three.number).version(2).shows(:set_properties => {ITERATION => '2'})
    assert_history_for(:card, @story_three.number).version(3).shows(:set_properties => {USER_PROPERTY => @mingle_admin.login})
    assert_history_for(:card, @story_three.number).version(4).shows(:set_properties => {DATE_PROPERTY => VALID_DATE})
    assert_history_for(:card, @story_three.number).version(5).shows(:set_properties => {FREE_TEXT_PROPERTY => TEXT})
  end

  def test_regular_team_member_cannot_update_values_for_protected_properties_on_card
    make_property_transition_only_for(@project, ITERATION)
    assert_notice_message("Property #{ITERATION} can now only be changed through a transition.")
    make_property_transition_only_for(@project, USER_PROPERTY)
    assert_notice_message("Property #{USER_PROPERTY} can now only be changed through a transition.")
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    assert_notice_message("Property #{FREE_TEXT_PROPERTY} can now only be changed through a transition.")
    make_property_transition_only_for(@project, DATE_PROPERTY)
    assert_notice_message("Property #{DATE_PROPERTY} can now only be changed through a transition.")

    logout
    login_as_team_member

    open_card(@project, @story_one)
    assert_property_not_editable_on_card_show(ITERATION)
    assert_property_not_editable_on_card_show(USER_PROPERTY)
    assert_property_not_editable_on_card_show(DATE_PROPERTY)
    # sleep 30
    assert_property_not_editable_on_card_show(FREE_TEXT_PROPERTY)

    open_card_for_edit(@project, @story_one)
    assert_property_not_editable_on_card_edit(ITERATION)
    assert_property_not_editable_on_card_edit(USER_PROPERTY)
    assert_property_not_editable_on_card_edit(DATE_PROPERTY)
    assert_property_not_editable_on_card_edit(FREE_TEXT_PROPERTY)

    #for bulk edit #2442
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    assert_property_not_editable_in_bulk_edit_properties_panel(@project, ITERATION)
    assert_property_not_editable_in_bulk_edit_properties_panel(@project, USER_PROPERTY)

    #TODO this will be comment back after story #4183 is finished
    # assert_property_not_editable_in_bulk_edit_properties_panel(@project, DATE_PROPERTY)
    # assert_property_not_editable_in_bulk_edit_properties_panel(@project, FREE_TEXT_PROPERTY)

    header_row = ['number', ITERATION, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY]
    card_data = [[@story_two.number, '2', "#{@project_admin.login}", VALID_DATE, 'text for free text']]
    preview(excel_copy_string(header_row, card_data))
    [DATE_PROPERTY, ITERATION, USER_PROPERTY, FREE_TEXT_PROPERTY].each do |property|
      assert_warning_message_matches("Property #{property} is transition only and will be ignored when updating cards. When creating new cards, these values will be set.")
    end
    open_card(@project, @story_two.number)
    assert_history_for(:card, @story_two.number).version(2).not_present
  end

  def test_team_member_can_set_protected_properties_during_card_creation
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)
    logout
    login_as_team_member

    navigate_to_card_list_for(@project)
    add_card_with_detail_via_quick_add('new card')
    set_properties_in_card_edit(:Type => STORY, ITERATION => 2, USER_PROPERTY => @mingle_admin.name)
    add_new_value_to_property_on_card_edit(@project, DATE_PROPERTY, ANOTHER_VALID_DATE)
    add_new_value_to_property_on_card_edit(@project, FREE_TEXT_PROPERTY, TEXT)
    save_card
    add_more_detail_card_number = find_card_by_name('new card').number
    open_card(@project, add_more_detail_card_number)
    assert_history_for(:card, add_more_detail_card_number).version(1).shows(:set_properties => {:Type => STORY})
    assert_history_for(:card, add_more_detail_card_number).version(1).shows(:set_properties => {ITERATION => '2'})
    assert_history_for(:card, add_more_detail_card_number).version(1).shows(:set_properties => {USER_PROPERTY => @mingle_admin.name})
    assert_history_for(:card, add_more_detail_card_number).version(1).shows(:set_properties => {DATE_PROPERTY => ANOTHER_VALID_DATE})
    assert_history_for(:card, add_more_detail_card_number).version(1).shows(:set_properties => {FREE_TEXT_PROPERTY => TEXT})
    assert_history_for(:card, add_more_detail_card_number).version(2).not_present
  end

  def test_team_member_when_click_save_and_add_another_card_in_card_show_will_carry_protected_property_value
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)
    open_card(@project, @story_one)
    click_edit_link_on_card
    set_properties_in_card_edit(ITERATION => 2, USER_PROPERTY => @mingle_admin.name)
    add_new_value_to_property_on_card_edit(@project, DATE_PROPERTY, ANOTHER_VALID_DATE)
    add_new_value_to_property_on_card_edit(@project, FREE_TEXT_PROPERTY, TEXT)
    save_card
    logout
    login_as_team_member

    navigate_to_card_list_for(@project)
    open_card(@project, @story_one)
    click_edit_link_on_card
    click_save_and_add_another_link
    assert_notice_message("Card ##{@story_one.number} was successfully updated.")
    assert_properties_set_on_card_edit(ITERATION => '2', USER_PROPERTY => ADMIN_NAME_TRUNCATED)
    assert_properties_set_on_card_edit(DATE_PROPERTY => '10 Apr 1980', FREE_TEXT_PROPERTY => TEXT)
  end

  def test_hidden_and_locked_properties_can_be_protected
    hide_property(@project, STATUS)
    lock_property(@project, STATUS)
    make_property_transition_only_for(@project, STATUS)
    assert_notice_message("Property #{STATUS} can now only be changed through a transition.")
    assert_hidden_is_checked_for(@project, STATUS)
    assert_locked_for(@project, STATUS)
    assert_transition_only_is_checked_for(@project, STATUS)
  end

  def test_protected_properties_survive_template_creation
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)
    make_property_transition_only_for(@project, STATUS)
    lock_property(@project, STATUS)
    hide_property(@project, STATUS)

    navigate_to_all_projects_page
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"

    project_from_template_name = 'testing_project_from_template'
    create_new_project(project_from_template_name, :template_identifier => template_identifier)
    navigate_to_property_management_page_for(project_from_template_name)
    assert_transition_only_is_checked_for(project_from_template_name, ITERATION)
    assert_transition_only_is_checked_for(project_from_template_name, USER_PROPERTY)
    assert_transition_only_is_checked_for(project_from_template_name, FREE_TEXT_PROPERTY)
    assert_transition_only_is_checked_for(project_from_template_name, DATE_PROPERTY)
    assert_transition_only_is_checked_for(project_from_template_name, STATUS)
    assert_hidden_is_checked_for(project_from_template_name, STATUS)
    assert_locked_for(project_from_template_name, STATUS)
  end

  def test_regular_team_members_can_change_protected_properties_via_transitions
    fake_now(2012, 10, 31)
    today = '31 Oct 2012'
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)
    transtion = create_transition_for(@project, 'testing set properties', :type => STORY,
      :set_properties => {ITERATION => 2, USER_PROPERTY => @project_admin.name, DATE_PROPERTY=> '(today)', FREE_TEXT_PROPERTY => TEXT})

    logout
    login_as_team_member
    open_card(@project, @story_one)
    click_transition_link_on_card(transtion)
    @browser.run_once_history_generation
    open_card(@project, @story_one)
    assert_history_for(:card, @story_one.number).version(2).shows(:set_properties => {ITERATION => '2'})
    assert_history_for(:card, @story_one.number).version(2).shows(:set_properties => {USER_PROPERTY => @project_admin.name})
    assert_history_for(:card, @story_one.number).version(2).shows(:set_properties => {DATE_PROPERTY => today})
    assert_history_for(:card, @story_one.number).version(2).shows(:set_properties => {FREE_TEXT_PROPERTY => TEXT})
    assert_history_for(:card, @story_one.number).version(3).not_present
  ensure
    @browser.reset_fake
  end

  # bug 2501
  def test_team_member_can_set_protected_properties_during_card_creation
    some_text = 'some text'
    make_property_transition_only_for(@project, ITERATION)
    make_property_transition_only_for(@project, USER_PROPERTY)
    make_property_transition_only_for(@project, FREE_TEXT_PROPERTY)
    make_property_transition_only_for(@project, DATE_PROPERTY)
    logout
    login_as_team_member

    navigate_to_card_list_for(@project)
    excel_import_card_number = '100'
    header_row = ['numer', ITERATION, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY]
    card_data = [[excel_import_card_number, '4', "#{@project_admin.login}", VALID_DATE, some_text]]
    import(excel_copy_string(header_row, card_data))
    open_card(@project, excel_import_card_number)
    truncated_proj_admin_name = @project_admin.name[0..9]
    assert_properties_set_on_card_show(ITERATION =>'4', USER_PROPERTY => "#{truncated_proj_admin_name}...")
    click_edit_link_on_card
    assert_properties_set_on_card_edit(DATE_PROPERTY => VALID_DATE, FREE_TEXT_PROPERTY => some_text)
    @browser.run_once_history_generation
    open_card(@project, excel_import_card_number)
    assert_history_for(:card, excel_import_card_number).version(1).shows(:set_properties => {ITERATION => '4'})
    assert_history_for(:card, excel_import_card_number).version(1).shows(:set_properties => {USER_PROPERTY => @project_admin.login})
    assert_history_for(:card, excel_import_card_number).version(1).shows(:set_properties => {DATE_PROPERTY => VALID_DATE})
    assert_history_for(:card, excel_import_card_number).version(1).shows(:set_properties => {FREE_TEXT_PROPERTY => some_text})
  end

  # bug 4779
  def test_should_be_able_to_disassociate_card_type_from_a_transition_only_property
    make_property_transition_only_for(@project, STATUS)
    assert_notice_message("Property #{STATUS} can now only be changed through a transition.")
    edit_property_definition_for(@project, STATUS, :card_types_to_uncheck => [STORY])
    assert_notice_message("Property was successfully updated.")

    open_card(@project, @story_one)
    assert_property_not_present_on_card_show(STATUS)
  end

  def login_as_team_member
    login_as(@team_member.login)
  end
end
