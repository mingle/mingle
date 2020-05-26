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

# Tags: scenario, properties, card-type, defaults
class Scenario60CardDefaultsCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  DEFECT = 'defect'
  STORY = 'story'
  TASK = 'Task'

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  PRIORITY = 'priority'
  HIGH = 'high'
  LOW = 'low'
  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'
  TODAY = '(today)'
  BLANK = ''
  NOT_SET = '(not set)'
  SIZE = 'size'
  CURRENT_USER= '(current user)'
  CARD = 'Card'


  ADMIN_NAME_TRUNCATED = "admin@emai..."
  PROJECT_MEMBER_NAME_TRUNCATED = "member@ema..."

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_60', :admins => [@project_admin], :users => [@admin, @project_member])
    setup_property_definitions(STATUS => [NEW, OPEN], PRIORITY => [HIGH, LOW])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    login_as_proj_admin_user
    @project.time_zone = ActiveSupport::TimeZone.new("London").name
    @project.save!
  end

  def test_tooltip_and_inline_imgae_for_property_on_card_default_edit_page
    @project.all_property_definitions.find_by_name(USER_PROPERTY).update_attributes(:description => "this property indicates who is the owner of the card.")

    open_edit_defaults_page_for(@project, CARD)
    wait_for_wysiwyg_editor_ready
    assert_property_tooltip_on_card_default_page(USER_PROPERTY)
    @browser.assert_element_not_present CardEditPageId::INSERT_IMAGE_TOOL_ID
  end

  def test_search_and_select_value_for_managed_text_managed_number_and_user_type_property_on_card_default
    admin_name = @admin.name
    project_admin_name = @project_member.name
    project_member_name = @project_member.name
    setup_numeric_property_definition(SIZE, [1, 2, 3, 4])

    open_edit_defaults_page_for(@project, CARD)

    click_property_on_card_defaults(USER_PROPERTY)
    select_property_drop_down_value(USER_PROPERTY, CURRENT_USER, "defaults")
    assert_property_set_on_card_defaults(@project, USER_PROPERTY, CURRENT_USER)

    # search value for user type property
    click_property_on_card_defaults(USER_PROPERTY)
    assert_values_present_in_property_drop_down(USER_PROPERTY, [CURRENT_USER, NOT_SET, admin_name, project_member_name, project_admin_name], "defaults")
    enter_search_value_for_property_editor_drop_down(USER_PROPERTY, "hello", "defaults")
    assert_values_not_present_in_property_drop_down(USER_PROPERTY, [CURRENT_USER, NOT_SET, admin_name, project_member_name, project_admin_name], "defaults")

    # search value for managed text property
    click_property_on_card_defaults(PRIORITY)
    assert_values_present_in_property_drop_down(PRIORITY, [NOT_SET, HIGH, LOW], "defaults")
    enter_search_value_for_property_editor_drop_down(PRIORITY, "HELLO", "defaults")
    assert_values_not_present_in_property_drop_down(PRIORITY, [NOT_SET, HIGH, LOW], "defaults")
    enter_search_value_for_property_editor_drop_down(PRIORITY, "I", "defaults")
    assert_values_present_in_property_drop_down(PRIORITY, [HIGH], "defaults")
    assert_values_not_present_in_property_drop_down(PRIORITY, [NOT_SET, LOW], "defaults")
    enter_search_value_for_property_editor_drop_down(PRIORITY, "Lo", "defaults")
    assert_values_not_present_in_property_drop_down(PRIORITY, [NOT_SET, HIGH], "defaults")
    assert_values_present_in_property_drop_down(PRIORITY, [LOW], "defaults")
    select_property_drop_down_value(PRIORITY, LOW, "defaults")
    assert_property_set_on_card_defaults(@project, PRIORITY, LOW)

    # search value for managed number property
    click_property_on_card_defaults(SIZE)
    enter_search_value_for_property_editor_drop_down(SIZE, "HELLO", "defaults")

    assert_values_not_present_in_property_drop_down(SIZE, [NOT_SET, "1", "2", "3", "4"], "defaults")
    enter_search_value_for_property_editor_drop_down(SIZE, "N", "defaults")

    assert_values_present_in_property_drop_down(SIZE, [NOT_SET], "defaults")
    assert_values_not_present_in_property_drop_down(SIZE, ["1", "2", "3", "4"], "defaults")
    enter_search_value_for_property_editor_drop_down(SIZE, "1", "defaults")
    assert_values_present_in_property_drop_down(SIZE, ["1"], "defaults")
    assert_values_not_present_in_property_drop_down(SIZE, ["2", "3", "4"], "defaults")
    select_property_drop_down_value(SIZE, "1", "defaults")
    assert_property_set_on_card_defaults(@project, SIZE, "1")
  end

  def test_removing_team_members_does_not_remove_current_user_from_user_property_on_card_defaults
    current_user = '(current user)'
    setup_card_type(@project, STORY, :properties => [USER_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, USER_PROPERTY => current_user)
    click_save_defaults
    remove_from_team_for(@project, @project_member)
    open_edit_defaults_page_for(@project, STORY)
    assert_properties_set_on_card_defaults(@project, USER_PROPERTY => current_user)


    # 6612 scenario 5 auto enrol user should be displayed in drop down list of user type property when edit card defaults

    logout
    login_as_admin_user
    navigate_to_user_management_page
    click_new_user_link
    new_user = add_new_user("new_user@gmail.com", "password1.")
    add_full_member_to_team_for(@project, new_user)

    open_edit_defaults_page_for(@project, STORY)
    assert_values_present_in_property_drop_down(USER_PROPERTY, [new_user.name], "defaults")
    @browser.click_and_wait('link=Cancel')
  end

  def test_cannot_use_defaults_across_projects
    setup_card_type(@project, DEFECT, :properties => [STATUS, PRIORITY])

    decoy_project = create_project(:prefix => 'scenario_60_decoy', :users => [@project_admin])
    setup_property_definitions(STATUS => [NEW, OPEN], PRIORITY => [HIGH, LOW])
    setup_card_type(decoy_project, DEFECT, :properties => [STATUS, PRIORITY])

    open_project(@project)
    @project.activate
    open_edit_defaults_page_for(@project, DEFECT)
    defect_default_description_in_real_project = "defect defaults for real PROJECT 60"
    type_description_defaults(defect_default_description_in_real_project)
    set_property_defaults(@project, STATUS => NEW, PRIORITY => HIGH)
    click_save_defaults
    card_in_real_project_number = add_new_card('foo', :type => DEFECT)
    open_card(@project, card_in_real_project_number)
    assert_card_description_in_show(defect_default_description_in_real_project)
    assert_properties_set_on_card_show(STATUS => NEW, PRIORITY => HIGH)

    open_project(decoy_project)
    decoy_project.activate
    card_in_decoy_number = add_new_card('decoy foo', :type => DEFECT)
    open_card(decoy_project, card_in_decoy_number)
    assert_card_description_in_show_does_not_match(defect_default_description_in_real_project)
    assert_properties_not_set_on_card_show(STATUS, PRIORITY)
    decoy_project.deactivate
  end

  def test_properties_that_are_not_specific_to_type_do_not_appear_on_edit_default_page
    setup_card_type(@project, DEFECT, :properties => [STATUS, USER_PROPERTY, FREE_TEXT_PROPERTY])
    setup_card_type(@project, STORY, :properties => [PRIORITY, DATE_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    assert_property_not_present_on_card_defaults(PRIORITY)
    assert_property_not_present_on_card_defaults(DATE_PROPERTY)
    assert_property_present_on_card_defaults(STATUS)
    assert_property_present_on_card_defaults(USER_PROPERTY)
    assert_property_present_on_card_defaults(FREE_TEXT_PROPERTY)
    open_edit_defaults_page_for(@project, STORY)
    assert_property_present_on_card_defaults(PRIORITY)
    assert_property_present_on_card_defaults(DATE_PROPERTY)
    assert_property_not_present_on_card_defaults(STATUS)
    assert_property_not_present_on_card_defaults(USER_PROPERTY)
    assert_property_not_present_on_card_defaults(FREE_TEXT_PROPERTY)
  end

  def test_using_inline_value_add_on_card_defaults_adds_value_to_property
    new_value = 'new Value'
    setup_card_type(@project, DEFECT, :properties => [STATUS])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults_via_inline_value_add(@project, STATUS, new_value)
    click_save_defaults
    navigate_to_property_management_page_for(@project)
    status_property_def = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    assert_property_does_have_value(status_property_def, new_value)
  end

  def test_renaming_card_type_does_not_lose_default_settings
    setup_card_type(@project, STORY, :properties => [STATUS, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    default_description = 'STUFF TO DO:'
    free_text_property_value = 'value for testing'
    type_description_defaults(default_description)
    set_property_defaults(@project, STATUS => OPEN)
    set_property_defaults(@project, USER_PROPERTY => @admin.name)
    set_property_defaults(@project, DATE_PROPERTY => TODAY)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, free_text_property_value)
    click_save_defaults
    edit_card_type_for_project(@project, STORY, :new_card_type_name => TASK)
    card_number = add_new_card('testing defaults', :type => TASK)
    open_card(@project, card_number)
    assert_card_type_set_on_card_show(TASK)
    assert_card_description_in_show(default_description)
    assert_properties_set_on_card_show(STATUS => OPEN, USER_PROPERTY => ADMIN_NAME_TRUNCATED)
    assert_properties_set_on_card_show(DATE_PROPERTY => today_in_project_format, FREE_TEXT_PROPERTY => free_text_property_value)

    open_edit_defaults_page_for(@project, TASK)
    assert_default_description(default_description)
    assert_properties_set_on_card_defaults(@project, STATUS => OPEN, USER_PROPERTY => ADMIN_NAME_TRUNCATED, DATE_PROPERTY => TODAY, FREE_TEXT_PROPERTY => free_text_property_value)
  end

  def test_non_admin_team_members_and_non_team_members_cannot_edit_card_defaults
    setup_card_type(@project, STORY, :properties => [PRIORITY])
    logout
    login_as_project_member
    open_edit_defaults_page_for(@project, STORY, :error => true)
    assert_cannot_access_resource_error_message_present

    logout
    login_as_non_project_member
    open_edit_defaults_page_for(@project, STORY, :error => true)
    assert_cannot_access_resource_error_message_present
  end

  def test_can_delete_card_types_that_have_defaults_set_but_are_not_used_by_cards
    setup_card_type(@project, DEFECT, :properties => [STATUS, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    default_description = 'STUFF TO DO:'
    free_text_property_value = 'value for testing'
    type_description_defaults(default_description)
    set_property_defaults(@project, STATUS => OPEN)
    set_property_defaults(@project, USER_PROPERTY => @project_member.name)
    set_property_defaults(@project, DATE_PROPERTY => TODAY)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, free_text_property_value)
    click_save_defaults
    delete_card_type(@project, DEFECT)
    assert_notice_message("Card Type #{DEFECT} was successfully deleted")
    assert_card_type_not_present_on_card_type_management_page(DEFECT)
  end

  def test_cancel_on_card_default_create_screen_does_not_save_changes
    setup_card_type(@project, STORY, :properties => [PRIORITY, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    default_description = 'h3. requirements:'
    free_text_property_value = 'value for testing'
    type_description_defaults(default_description)
    set_property_defaults(@project, PRIORITY => LOW)
    set_property_defaults(@project, USER_PROPERTY => @project_member.name)
    set_property_defaults(@project, DATE_PROPERTY => TODAY) # bug 7418
    set_property_defaults(@project, DATE_PROPERTY => NOT_SET) # bug 7418
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, free_text_property_value)
    click_cancel_link
    open_edit_defaults_page_for(@project, STORY)
    assert_default_description(BLANK)
    assert_properties_set_on_card_defaults(@project, PRIORITY => NOT_SET, USER_PROPERTY => NOT_SET, DATE_PROPERTY => NOT_SET, FREE_TEXT_PROPERTY => NOT_SET)
  end

  def test_deleting_property_removes_it_from_defaults
    setup_card_type(@project, DEFECT, :properties => [STATUS, PRIORITY, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    default_description = 'reproduction steps:'
    free_text_property_value = 'value for testing'
    type_description_defaults(default_description)
    set_property_defaults(@project, STATUS => NOT_SET)
    set_property_defaults(@project, PRIORITY => HIGH)
    set_property_defaults(@project, USER_PROPERTY => @project_member.name)
    set_property_defaults(@project, DATE_PROPERTY => TODAY)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, free_text_property_value)
    click_save_defaults
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS)
    delete_property_for(@project, PRIORITY)
    delete_property_for(@project, USER_PROPERTY)
    delete_property_for(@project, DATE_PROPERTY)
    delete_property_for(@project, FREE_TEXT_PROPERTY)
    open_edit_defaults_page_for(@project, DEFECT)
    assert_default_description(default_description)
    assert_property_not_present_on_card_defaults(STATUS)
    assert_property_not_present_on_card_defaults(PRIORITY)
    assert_property_not_present_on_card_defaults(USER_PROPERTY)
    assert_property_not_present_on_card_defaults(DATE_PROPERTY)
    assert_property_not_present_on_card_defaults(FREE_TEXT_PROPERTY)
  end

  # bug 3712
  def test_deleting_enumerated_property_that_is_used_by_multiple_card_types_removes_it_from_both_defaults
    setup_card_type(@project, DEFECT, :properties => [STATUS, PRIORITY, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    setup_card_type(@project, STORY, :properties => [STATUS, PRIORITY, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    default_description = 'reproduction steps:'
    free_text_property_value = 'value for testing'
    type_description_defaults(default_description)
    set_property_defaults(@project, STATUS => NOT_SET)
    set_property_defaults(@project, PRIORITY => HIGH)
    set_property_defaults(@project, USER_PROPERTY => @project_member.name)
    set_property_defaults(@project, DATE_PROPERTY => TODAY)
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, free_text_property_value)
    click_save_defaults
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, STATUS)
    open_edit_defaults_page_for(@project, DEFECT)
    assert_default_description(default_description)
    assert_property_not_present_on_card_defaults(STATUS)
    assert_properties_set_on_card_defaults(@project, PRIORITY => HIGH, USER_PROPERTY => PROJECT_MEMBER_NAME_TRUNCATED, DATE_PROPERTY=> TODAY, FREE_TEXT_PROPERTY => free_text_property_value)
    open_edit_defaults_page_for(@project, STORY)
    assert_property_not_present_on_card_defaults(STATUS)
    assert_property_present_on_card_defaults(PRIORITY)
    assert_property_present_on_card_defaults(USER_PROPERTY)
    assert_property_present_on_card_defaults(DATE_PROPERTY)
    assert_property_present_on_card_defaults(FREE_TEXT_PROPERTY)
  end

  def test_renaming_property_correctly_changes_card_defaults_page
    setup_card_type(@project, DEFECT, :properties => [DATE_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    default_description = 'reproduction steps:'
    type_description_defaults(default_description)
    set_property_defaults(@project, DATE_PROPERTY => TODAY)
    click_save_defaults
    new_name_for_property = 'fixed on'
    edit_property_definition_for(@project, DATE_PROPERTY, :new_property_name => new_name_for_property)
    open_edit_defaults_page_for(@project, DEFECT)
    wait_for_wysiwyg_editor_ready
    assert_default_description(default_description)
    assert_properties_set_on_card_defaults(@project, new_name_for_property => TODAY)
  end

  def test_renaming_property_value_updates_value_on_card_defaults
    setup_card_type(@project, STORY, :properties => [PRIORITY])
    open_edit_defaults_page_for(@project, STORY)
    default_description = 'requirements:'
    set_property_defaults(@project, PRIORITY => HIGH)
    click_save_defaults
    navigate_to_property_management_page_for(@project)
    new_name_for_high = 'URGENT'
    edit_enumeration_value_for(@project, PRIORITY, HIGH, new_name_for_high)
    open_edit_defaults_page_for(@project, STORY)
    assert_properties_set_on_card_defaults(@project, PRIORITY => new_name_for_high)
    card_number = add_new_card('testing defaults', :type => STORY)
    open_card(@project, card_number)
    assert_card_type_set_on_card_show(STORY)
    assert_properties_set_on_card_show(PRIORITY => new_name_for_high)
  end

  def test_removing_team_member_removes_them_from_user_property_on_card_defaults
    setup_card_type(@project, STORY, :properties => [USER_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, USER_PROPERTY => @project_member.name)
    click_save_defaults
    remove_from_team_for(@project, @project_member, :update_permanently => true)
    open_edit_defaults_page_for(@project, STORY)
    assert_properties_set_on_card_defaults(@project, USER_PROPERTY => NOT_SET)
    card_number = add_new_card('testing defaults', :type => STORY)
    open_card(@project, card_number)
    assert_card_type_set_on_card_show(STORY)
    assert_properties_set_on_card_show(USER_PROPERTY => NOT_SET)
  end

  def test_admins_can_set_hidden_properties_on_card_defaults
    setup_card_type(@project, STORY, :properties => [FREE_TEXT_PROPERTY, USER_PROPERTY, STATUS])
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)
    hide_property(@project, STATUS)
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults(@project, STATUS => NEW)
    set_property_defaults(@project, USER_PROPERTY => @admin.name)
    free_text_property_value = 'value for testing'
    set_property_defaults_via_inline_value_add(@project, FREE_TEXT_PROPERTY, free_text_property_value)
    click_save_defaults
    open_edit_defaults_page_for(@project, STORY)
    assert_properties_set_on_card_defaults(@project, STATUS => NEW, USER_PROPERTY => ADMIN_NAME_TRUNCATED, FREE_TEXT_PROPERTY => free_text_property_value)
    card_number = add_new_card('testing hidden properties on defaults', :type => STORY)
    open_card(@project, card_number)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {STATUS => NEW, USER_PROPERTY => @admin.login, FREE_TEXT_PROPERTY => free_text_property_value})
  end

  def test_admins_can_set_locked_properties_on_card_defaults
    setup_card_type(@project, DEFECT, :properties => [PRIORITY])
    lock_property(@project, PRIORITY)
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, PRIORITY => HIGH)
    click_save_defaults
    open_edit_defaults_page_for(@project, DEFECT)
    assert_properties_set_on_card_defaults(@project, PRIORITY => HIGH)
    card_number = add_new_card('testing locked properties on defaults', :type => DEFECT)
    open_card(@project, card_number)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {PRIORITY => HIGH})
  end

  def test_changing_project_date_format_changes_date_property_on_default
    fake_now(1979, 12, 2)
    valid_date_in_new_format = '1979/12/02'
    setup_card_type(@project, DEFECT, :properties => [DATE_PROPERTY])
    open_edit_defaults_page_for(@project, DEFECT)
    set_property_defaults(@project, DATE_PROPERTY => TODAY)
    click_save_defaults
    navigate_to_project_admin_for(@project)
    set_project_date_format('yyyy/mm/dd')
    open_edit_defaults_page_for(@project, DEFECT)
    assert_properties_set_on_card_defaults(@project, DATE_PROPERTY => TODAY)
    card_number = add_new_card('testing project date format change in defaults', :type => DEFECT)
    open_card(@project, card_number)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {DATE_PROPERTY => valid_date_in_new_format})
  ensure
    @browser.reset_fake
  end

  # bug 2714
  def test_hidden_properties_can_be_associated_to_card_types_during_type_creation
    hide_property(@project, STATUS)
    hide_property(@project, USER_PROPERTY)
    open_create_new_card_type_page(@project)
    assert_property_present_on_card_type_edit_page(@project, STATUS)
    assert_property_present_on_card_type_edit_page(@project, USER_PROPERTY)
    clear_all_selected_properties_for_card_type
    check_the_properties_required_for_card_type(@project, [STATUS, USER_PROPERTY])
    type_card_type_name(STORY)
    click_create_card_type
    open_edit_card_type_page(@project, STORY)
    assert_properties_selected_for_card_type(@project, STATUS, USER_PROPERTY)
  end

  # bug 2714
  def test_associations_to_hidden_properties_can_be_added_to_existing_card_types
    setup_card_type(@project, STORY, :properties => [FREE_TEXT_PROPERTY])
    hide_property(@project, STATUS)
    hide_property(@project, USER_PROPERTY)
    open_edit_card_type_page(@project, STORY)
    assert_properties_selected_for_card_type(@project, FREE_TEXT_PROPERTY)
    assert_property_present_on_card_type_edit_page(@project, STATUS)
    assert_property_present_on_card_type_edit_page(@project, USER_PROPERTY)
    check_the_properties_required_for_card_type(@project, [STATUS, USER_PROPERTY])
    save_card_type
    open_edit_card_type_page(@project, STORY)
    assert_properties_selected_for_card_type(@project, STATUS, USER_PROPERTY, FREE_TEXT_PROPERTY)
  end

  # bug #9610
  def test_daily_history_chart_should_show_message_on_card_defaults_preview
    setup_card_type(@project, STORY, :properties => [STATUS, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    description = %{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: 22 May 2010
        end-date: 23 May 2010
        series:
          - label:
    }
    create_free_hand_macro description
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS,"Your daily history chart will display upon saving")
  end

  #14473
  def test_daily_history_chart_should_not_throw_error_if_THIS_CARD_dot_date_user
    setup_card_type(@project, STORY, :properties => [STATUS, USER_PROPERTY, DATE_PROPERTY, FREE_TEXT_PROPERTY])
    open_edit_defaults_page_for(@project, STORY)
    description = %{
      daily-history-chart
        aggregate: COUNT(*)
        start-date: THIS CARD.#{DATE_PROPERTY}
        end-date: 23 May 2010
        series:
          - label:
    }
    create_free_hand_macro description
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS,"Macros using THIS CARD.#{DATE_PROPERTY} will be rendered when card is created using this card default.")
  end

end
