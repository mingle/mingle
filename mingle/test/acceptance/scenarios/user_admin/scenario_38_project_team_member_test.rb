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

# Tags: scenario, user, #1561, #1569, #1576, #1575, #2503, #2505
class Scenario38ProjectTeamMemberTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'Status'
  NEW = 'new'
  OPEN = 'open'
  CARD = 'Card'
  TYPE = 'Type'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin_user = users(:admin)
    @team_member_user = users(:longbob)
    @non_team_member_user = users(:existingbob)
    @project = create_project(:prefix => 'scenario_38', :users => [@admin_user, @team_member_user])
    setup_property_definitions(:Status => [NEW, OPEN])
    @decoy_project = create_project(:prefix => 'decoy_project', :users => [@admin_user])
  end

  def test_team_member_can_add_or_remove_lanes_or_columns_in_grid_or_list_view
    login_as_team_member
    @project.activate
    @card = create_card!(:name => 'first card')
    navigate_to_grid_view_for(@project)
    group_columns_by(STATUS)
    assert_lane_not_present(STATUS,NEW)
    add_lanes(@project, STATUS, [NEW])
    assert_lane_present(STATUS,NEW)

    navigate_to_card_list_for(@project)
    add_column_for(@project, [TYPE])
    assert_column_present_for(TYPE)
  end

  def test_team_member_cannot_create_or_delete_new_project_or_template
    login_as_admin_user
    create_template_for(@project)
    logout
    login_as_team_member
    @browser.assert_element_not_present("action-bar")
    assert_link_not_present_and_cannot_access_via_browser("/admin/projects/new")
    assert_link_not_present_and_cannot_access_via_browser("/admin/projects/import")
    assert_link_not_present_and_cannot_access_via_browser("/admin/templates")
    @browser.assert_element_not_present("create_template_#{@project.identifier}")
    assert_link_not_present_and_cannot_access_via_browser("/admin/templates/templatize/#{@project.identifier}")
    assert_link_not_present_and_cannot_access_via_browser("/projects/#{@project.identifier}/admin/delete")
    assert_link_not_present_and_cannot_access_via_browser("/admin/templates/delete/#{@project.identifier}_template") # bug 1569
  end

  #bug 5587
  def test_team_member_should_not_be_able_to_delete_wiki_pages
    login_as_admin_user
    wiki_name = "2.2 release"
    new_wiki = create_a_wiki_page_with_text(@project, wiki_name, "try to delete me")
    open_wiki_page(@project, wiki_name)
    assert_delete_link_present
    login_as_team_member
    open_wiki_page(@project, wiki_name)
    assert_delete_link_not_present
  end

  def test_team_member_cannot_edit_existing_project
    login_as_team_member
    open_project_admin_for(@project)
    @browser.assert_location("/projects/#{@project.identifier}/team/list")
    @browser.open("/projects/#{@project.identifier}/projects/edit/#{@project.id}")
    assert_cannot_access_resource_error_message_present
  end

  def test_project_admin_cannot_create_new_or_edit_exisiting_users
    login_as_team_member
    assert_link_not_present_and_cannot_access_via_browser("/users/list")
    assert_cannot_access_via_browser("/users/new")
    assert_cannot_access_via_browser("/users/edit_profile/#{@non_team_member_user.id}")
    assert_cannot_access_via_browser("/users/edit_profile/#{@admin_user.id}")
  end

  def test_team_list_is_readonly_for_team_members
    login_as_team_member
    open_project_admin_for(@project)
    @browser.assert_element_not_present("action-bar")
    assert_member_can_not_be_removed
    assert_project_admin_check_box_disabled_for(@admin_user)
    assert_member_can_not_be_removed
    assert_project_admin_check_box_disabled_for(@team_member_user)
    assert_user_is_not_team_member(@non_team_member_user)
  end

  # bug 1561
  def test_card_properties_are_read_only
    property_def = lock_property_via_model(@project, STATUS)
    enum_value_new = Project.find_by_identifier(@project.identifier).with_active_project do |proj|
      proj.find_enumeration_value(property_def.name, NEW)
    end
    login_as_team_member
    navigate_to_property_management_page_for(@project)
    @browser.assert_element_not_present("link=Create new card property") #bug 2503
    @browser.assert_element_not_present("delete_property_def_#{property_def.id}")
    assert_lock_check_box_disabled_for(@project, property_def)
    assert_hide_check_box_disabled_for(@project, property_def)
    assert_transition_only_check_box_disabled(@project, STATUS)
    @browser.click_and_wait("id=enumeration-values-#{property_def.id}")
    @browser.assert_element_not_present("link=Edit Property")
    @browser.assert_element_not_present("enumeration_value_input_box")
    @browser.assert_element_not_present("drag_enumeration_value_#{enum_value_new.id}")
    @browser.assert_element_not_present("delete-value-#{enum_value_new.id}")
    @browser.assert_element_not_present("edit-value-#{enum_value_new.id}")
    assert_link_not_present("/projects/#{@project.identifier}/property_definitions/edit/#{property_def.id}")

    assert_cannot_access_via_browser("/projects/#{@project.identifier}/property_definitions/toggle_restricted/#{property_def.id}")
    assert_cannot_access_via_browser("/projects/#{@project.identifier}/property_definitions/confirm_hide?name=#{property_def.name}")
    assert_cannot_access_via_browser("/projects/#{@project.identifier}/enumeration_values/create?property_definition=#{property_def.id}")
    assert_cannot_access_via_browser("/projects/#{@project.identifier}/property_definitions/new")
  end

  def test_team_member_cannot_create_new_property_via_excel_import
    login_as_team_member
    navigate_to_card_list_by_clicking(@project)
    new_property = 'Foo'
    header_row = ['Number', new_property]
    card_data = [['478', 'bar']]
    import(excel_copy_string(header_row, card_data))

    assert_error_message("Error creating custom property (<b>)?Foo(</b>)?. You must be a project administrator to create custom properties.")
    @browser.assert_text_present ""
    @browser.assert_text_present ""
    click_all_tab
    assert_info_message("There are no cards for #{@project.name}")
  end

  # bug 1576 & 1575
  def test_team_member_cannot_delete_card
    login_as_team_member
    @project.activate
    card = create_card!(:name => "dev's story")
    open_card(@project, card.number)
    @browser.assert_element_not_present("link=Delete")
    assert_link_not_present("/projects/#{@project.identifier}/cards/#{card.number}/destroy")

    navigate_to_card_list_for(@project)
    select_all
    @browser.assert_element_not_present('bulk-delete-button')
  end
  # bug 2506
  def test_card_properties_are_read_only_for_team_members
    property_def = lock_property_via_model(@project, STATUS)
    enum_value_new = Project.find_by_identifier(@project.identifier).with_active_project do |proj|
      proj.find_enumeration_value(property_def.name, NEW)
    end
    login_as_team_member
    navigate_to_property_management_page_for(@project)
    @browser.click_and_wait("enumeration-values-#{property_def.id}")
    @browser.assert_element_not_present("enumeration_value_input_box")
    @browser.assert_element_not_present("submit-quick-add")
  end

  # bug 4065
  def test_team_member_does_not_see_configure_tree_link_after_admin_has_logged_in
    login_as_admin_user
    @project.activate
    @type_card = @project.card_types.find_by_name('Card')
    @type_bug = setup_card_type(@project, 'Bug')

    tree = setup_tree(@project, 'Some Tree', :types => [@type_card, @type_bug], :relationship_names => ['Some Tree - Card'])

    card = create_card!(:name => 'first card', :type => @type_card.name)
    add_card_to_tree(tree, card)

    navigate_to_card_list_for(@project)
    select_tree(tree.name)
    assert_link_configure_tree_on_current_tree_configuration_widget

    logout
    login_as_team_member
    click_all_tab
    select_tree(tree.name)
    assert_link_configure_tree_not_present_on_current_tree_configuration_widget
  end

  # bug 4066
  def test_team_member_does_not_see_manage_favorites_link_after_admin_has_logged_in
    login_as_admin_user
    @project.activate

    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => TYPE, :value => CARD)
    create_card_list_view_for(@project, 'cards view')
    assert_manage_favorites_and_tabs_link_present

    logout
    login_as_team_member
    click_all_tab
    assert_manage_favorites_and_tabs_link_not_present
  end

  def login_as_team_member
    login_as("#{@team_member_user.login}", 'longtest')
  end

  def test_advanced_admin_page_is_not_visiable_for_project_team_member
    login_as_team_member
    open_project_admin_for(@project)
    assert_advanced_project_admin_link_is_not_present
  end

  def test_admin_tab_is_not_visible_for_team_member
     login_as_team_member
     navigate_to_programs_page
     assert_admin_pill_not_present
   end
end
