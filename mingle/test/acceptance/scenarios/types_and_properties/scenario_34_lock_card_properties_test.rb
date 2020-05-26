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

# Tags: scenario, properties, enum-property, cards
class Scenario34LockCardPropertiesTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'Status'
  NEW = 'new'
  IN_PROGRESS = 'in progress'

  PRIORITY = 'Priority'
  HIGH = 'high'
  LOW = 'low'

  FEATURE = 'Feature'
  CARDS = 'cards'
  WIKI = 'wiki'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_34', :users => [users(:admin)])
    setup_property_definitions(:Status => [NEW, IN_PROGRESS], :Priority => [HIGH, LOW], :Feature => [CARDS, WIKI])
    add_to_team_via_model_for(@project, @non_admin_user)
    add_to_team_as_project_admin_via_model_for(@project, @project_admin_user)
    login_as_admin_user
    @card = create_card!(:name => 'plain card')
  end

  def test_only_mingle_and_project_admin_can_lock_and_unlock_properties
    assert_can_lock_and_unlock_property(STATUS)
    logout

    login_as_proj_admin_user
    assert_can_lock_and_unlock_property(PRIORITY)
    lock_property(@project, STATUS)
    unlock_property(@project, STATUS)

    login_as_non_admin_user
    assert_can_not_lock_and_unlock_property(PRIORITY)
    assert_can_not_lock_and_unlock_property(STATUS)
  end

  def test_only_admins_can_add_new_values_to_locked_properties_on_property_management_screen
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    lock_property(@project, STATUS)
    create_enumeration_value_for(@project, STATUS, '1st new')
    navigate_to_property_management_page_for(@project)
    assert_property_does_have_value(status_property_definition, '1st new')
    logout

    login_as_proj_admin_user
    create_enumeration_value_for(@project, STATUS, '2nd new')
    navigate_to_property_management_page_for(@project)
    assert_property_does_have_value(status_property_definition, '2nd new')
    logout

    login_as_non_admin_user
    navigate_to_property_management_page_for(@project)
    @browser.click_and_wait("id=enumeration-values-#{status_property_definition.id}")
    assert_link_not_present_and_cannot_access_via_browser("/projects/#{@project.identifier}/enumeration_values/create?property_definition=#{status_property_definition.id}")
  end

  def test_cannot_add_new_enum_values_to_locked_properties_if_user_non_admin
    lock_property(@project, PRIORITY)
    navigate_to_card(@project, @card)
    assert_inline_enum_value_add_present_for(PRIORITY, "show")
    logout

    login_as_non_admin_user
    navigate_to_card(@project, @card)
    assert_inline_enum_value_add_not_present_for(PRIORITY, "show")
  end

  def test_cannot_add_new_enum_to_locked_property_via_excel_import_if_user_non_admin
    lock_property(@project, PRIORITY)
    navigate_to_card(@project, @card)
    assert_can_add_new_value_to_locked_property_via_excel_import_if_user_is_an_admin(PRIORITY, 'CLOSED BY MINGLE ADMIN')
    logout

    login_as_non_admin_user
    navigate_to_card(@project, @card)
    assert_cannot_add_new_value_to_locked_property_via_excel_import(PRIORITY, 'CLOSED BY MEMBER')
  end

  def test_cannot_add_new_enum_value_to_locked_property_via_bulk_update_if_user_non_admin
    lock_property(@project, PRIORITY)
    navigate_to_card(@project, @card)
    assert_inline_enum_value_add_present_on_bulk_edit_properties_for(@project, PRIORITY)
    logout

    login_as_non_admin_user
    navigate_to_card(@project, @card)
    assert_inline_enum_value_add_not_present_on_bulk_edit_properties_for(@project, PRIORITY)
  end

  def test_cannot_add_new_enum_value_to_locked_property_via_url_if_user_non_admin
    lock_property(@project, PRIORITY)
    navigate_to_card(@project, @card)
    assert_can_create_new_enum_value_for_locked_property_via_url_if_user_is_an_admin(PRIORITY, 'foo bar')
    logout

    login_as_non_admin_user
    navigate_to_card(@project, @card)
    assert_cannot_create_new_enum_value_for_locked_property_via_url(PRIORITY, 'bar')
  end

  def assert_cannot_create_new_enum_value_for_locked_property_via_url(property, new_value)
    @browser.open("/projects/#{@project.identifier}/cards/new?properties[#{property}]=#{new_value}")
    assert_property_set_on_card_edit(property, new_value)
    assert_locked_error_message_on_card_edit_page(property,'foo bar', HIGH, LOW)
    # todo: do we need to assert that the invalid property value is not in the drop list options?
    save_card_with_flash
    assert_property_set_on_card_edit(property, new_value)
    assert_locked_error_message_on_card_edit_page(property,'foo bar', HIGH, LOW)
  end

  def assert_can_create_new_enum_value_for_locked_property_via_url_if_user_is_an_admin(property, new_value)
    @browser.open("/projects/#{@project.identifier}/cards/new?properties[#{property}]=#{new_value}")
    assert_property_set_on_card_edit(property, new_value)
  end

  def test_admins_can_still_edit_and_delete_locked_properties_and_their_values
    status_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(STATUS)
    feature_property_definition = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(FEATURE)
    lock_property(@project, STATUS)
    edit_enumeration_value_for(@project, STATUS, NEW, 'nu')
    navigate_to_property_management_page_for(@project)
    assert_property_does_have_value(status_property_definition, 'nu')
    admins_renamed_property_def = edit_property_definition_for(@project, PRIORITY, :new_property_name => 'importance')
    assert_property_exists(admins_renamed_property_def)
    delete_enumeration_value_for(@project, FEATURE, CARDS)
    navigate_to_property_management_page_for(@project)
    assert_property_does_not_have_value(feature_property_definition, CARDS)
    logout

    login_as_proj_admin_user
    edit_enumeration_value_for(@project, STATUS, IN_PROGRESS, 'working')
    navigate_to_property_management_page_for(@project)
    assert_property_does_have_value(status_property_definition, 'working')
    proj_admins_renamed_property_def = edit_property_definition_for(@project, STATUS, :new_property_name => 'sup')
    assert_property_exists(proj_admins_renamed_property_def)
    delete_enumeration_value_for(@project, FEATURE, WIKI)
    navigate_to_property_management_page_for(@project)
    assert_property_does_not_have_value(feature_property_definition, WIKI)
  end

  def test_property_restriction_is_maintained_in_template_created_from_project
    lock_property(@project, PRIORITY)
    navigate_to_all_projects_page
    create_template_for(@project)
    template_identifier = "#{@project.identifier}_template"
    @browser.open("/projects/#{template_identifier}/property_definitions")
    assert_locked_for(template_identifier, PRIORITY)
    assert_unlocked_for(template_identifier, STATUS)
  end

  # bug 1436, 1438
  def test_user_properties_cannot_be_locked
    user_property_name = 'Assigned To'
    user_property = create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate

    navigate_to_property_management_page_for(@project)
    assert_lock_check_box_not_present_for(@project, user_property_name)
  end

  # bug 2256
  def test_admin_can_add_new_values_to_locked_property_during_transition_creation
    new_value = 'this is new'
    lock_property(@project, FEATURE)
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    type_transition_name('testing 2256')
    property_from_db = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(FEATURE)
    add_value_to_property_on_transition_sets(@project, FEATURE, new_value)
    click_create_transition
    open_card(@project, @card)
    set_properties_on_card_show(FEATURE => new_value)
    assert_history_for(:card, @card.number).version(2).shows(:set_properties => {FEATURE => new_value})
    navigate_to_property_management_page_for(@project)
    assert_property_does_have_value(property_from_db, new_value)
  end

  def test_admin_can_add_new_values_to_locked_property_on_card_defaults_page
    new_value = 'URGENT'
    story = 'STORY'
    lock_property(@project, PRIORITY)
    setup_card_type(@project, story, :properties => [PRIORITY])
    open_edit_defaults_page_for(@project, story)
    set_property_defaults_via_inline_value_add(@project, PRIORITY, new_value)
    click_save_defaults
    navigate_to_property_management_page_for(@project)
    property_from_db = Project.find_by_identifier(@project.identifier).find_property_definition_or_nil(PRIORITY)
    assert_property_does_have_value(property_from_db, new_value)
  end

  # bug 1429
  def assert_cannot_add_new_value_to_locked_property_via_excel_import(property, new_enum_value)
    header_row = ['Number', property]
    cards = [
      ['35', new_enum_value]
    ]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, cards))
    assert_locked_error_message_while_importing(property, 'CLOSED BY MINGLE ADMIN',HIGH, LOW)
  end

  def assert_can_add_new_value_to_locked_property_via_excel_import_if_user_is_an_admin(property, new_enum_value)
    header_row = ['Number', property]
    cards = [
      ['35', new_enum_value]
    ]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, cards))
    add_column_for(@project, [PRIORITY])

    cards = HtmlTable.new(@browser, 'cards', ['Number', 'Name', PRIORITY], 1, 1)
    cards.assert_row_values(1, ['35', "Card 35", new_enum_value])
  end

  def login_as_non_admin_user
    login_as("#{@non_admin_user.login}", 'longtest')
  end

  def assert_can_lock_and_unlock_property(property)
    navigate_to_property_management_page_for(@project)
    lock_property(@project, property)
    @browser.wait_for_element_present("notice")
    assert_notice_message("Property #{property} is now locked")
    unlock_property(@project, property)
    @browser.wait_for_element_present("notice")
    assert_notice_message("Property #{property} is now unlocked")
  end

  def assert_can_not_lock_and_unlock_property(property)
    navigate_to_property_management_page_for(@project)
    assert_lock_check_box_disabled_for(@project, property)
  end

  def assert_locked_error_message_while_importing(property, *enum_values)
    @browser.assert_text_present "Row 1: Validation failed: #{property} is restricted to #{enum_values.to_sentence}"
  end

  def assert_locked_error_message_on_card_edit_page(property, *enum_values)
    @browser.wait_for_element_present("css=#flash")
    message = @browser.get_text "css=#flash"
    assert_equal_ignoring_spaces "#{property} is restricted to #{enum_values.to_sentence}", message
  end
end
