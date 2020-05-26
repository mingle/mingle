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

# Tags: scenario, properties, user-property, enum-property, cards, gridview, #1321, #1322, #1333, #1334, #1421, #1445, #1454, #1479, #1534, #1584, #1587,
        #1621, #1625, #1627, #1628, #1710, #1886, #1887, #2129SR, #2272, #2441
class Scenario36UserPropertiesTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  NOT_SET = '(not set)'
  STATUS = 'Status'
  NEW = 'New'
  OPEN = 'Open'
  OWNER = 'owner'
  CURRENT_USER = '(current user)'

  PLANNING_TREE = 'planning tree'
  RELEASE = 'release'

  ADMIN_NAME_TRUNCATED = "admin@emai..."

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @admin = users(:admin)
    @team_member = users(:bob)
    @non_team_member = users(:longbob)
    @project = create_project(:prefix => 'scenario_36', :users => [@admin, @team_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    login_as_admin_user
    @card = create_card!(:name => 'plain card')
  end

  def test_search_and_select_value_for_user_property_on_card_edit
    admin_name = @admin.name
    team_member_name = @team_member.name
    create_property_definition_for(@project, OWNER, :type => 'user')
    navigate_to_card_list_for(@project)

    open_card_for_edit(@project,@card.number)
    click_property_on_card_edit(OWNER)
    assert_values_present_in_property_drop_down_on_card_edit(OWNER, [CURRENT_USER,NOT_SET,admin_name,team_member_name])
    type_keyword_to_search_value_for_property_on_card_edit(OWNER, "hello")
    assert_values_not_present_in_property_drop_down_on_card_edit(OWNER, [CURRENT_USER,NOT_SET,admin_name,team_member_name])
    type_keyword_to_search_value_for_property_on_card_edit(OWNER, "")
    assert_values_present_in_property_drop_down_on_card_edit(OWNER, [NOT_SET])
    select_value_in_drop_down_for_property_on_card_edit(OWNER, NOT_SET)
    assert_edit_property_set(OWNER, NOT_SET)
  end

  def test_search_and_select_value_for_user_property_on_card_show
    admin_name = @admin.name
    team_member_name = @team_member.name
    create_property_definition_for(@project, OWNER, :type => 'user')
    navigate_to_card_list_for(@project)

    open_card(@project,@card.number)
    click_property_on_card_show(OWNER)
    assert_value_present_in_property_drop_down_on_card_show(OWNER, [CURRENT_USER,NOT_SET,admin_name,team_member_name])
    type_keyword_to_search_value_for_property_on_card_show(OWNER, "hello")
    assert_value_not_present_in_property_drop_down_on_card_show(OWNER, [CURRENT_USER,NOT_SET,admin_name,team_member_name])
    type_keyword_to_search_value_for_property_on_card_show(OWNER, "")
    assert_value_present_in_property_drop_down_on_card_show(OWNER, [NOT_SET])
    select_value_in_drop_down_for_property_on_card_show(OWNER, NOT_SET)
    assert_property_set_on_card_show(OWNER, NOT_SET)
  end

  #bug 5108
  def test_using_a_renamed_team_member_to_access_a_favorite_that_filtered_with_this_team_member_old_name_should_work
    create_property_definition_for(@project, OWNER, :type => 'user')
    create_card!(:name => 'card for admin', :owner => @team_member.id)
    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => OWNER, :value => 'bob@email.com')
    favorite = create_card_list_view_for(@project, 'favorite one')
    login_as('bob')
    open_favorites_for(@project, favorite.name)
    open_edit_profile_for(@team_member)
    @browser.type('user_login', 'new_login_name')
    type_full_name_in_user_profile('new full name')
    click_save_profile_button
    open_project(@project)
    click_all_tab
    @browser.assert_text_present('Filter is invalid. bob is an unknown user.')
  end

  #bug 5174
  def test_filter_should_work_when_set_user_property_to_NOT_SET
    create_property_definition_for(@project, OWNER, :type => 'user')
    card1 = create_card!(:name => 'card for admin', :owner => @team_member.id)
    card2 = create_card!(:name => 'card for nobody', :owner => NOT_SET)
    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => OWNER, :value => NOT_SET)
    assert_card_present_in_list(card2)
    assert_card_present_in_list(@card)
    @browser.assert_text_not_present('Filter is invalid. is an unknown user. Reset filter')
  end

  def test_cannot_create_multiple_user_properties_with_the_same_name
    user_property_name = 'developed by'
    same_name_with_extra_spaces = 'developed    by'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    create_property_definition_for(@project, user_property_name.upcase, :type => 'user')
    assert_error_message('Name has already been taken')
    assert_error_message_does_not_contain('Column name has already been taken') # bug 1710
    @browser.assert_checked('definition_type_user') # bug 1322
    create_property_definition_for(@project, same_name_with_extra_spaces, :type => 'user')
    assert_error_message('Name has already been taken')
    assert_error_message_does_not_contain('Column name has already been taken')# bug 1710
  end

  def test_renaming_user_property_does_not_change_values_for_that_property_in_existing_transitions
    user_property_name = 'Assigned To'
    new_property_name = 'OWNER'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate

    transition_using_user_property = create_transition_for(@project, 'assigning', :required_properties => {user_property_name => @team_member.name},
                                                                                  :set_properties => {user_property_name => @admin.name})
    newly_named_property_defintion = edit_property_definition_for(@project, user_property_name, :new_property_name => new_property_name)
    open_transition_for_edit(@project, transition_using_user_property)
    @project.reload
    assert_requires_property(new_property_name => @team_member.name)
    assert_sets_property(new_property_name => ADMIN_NAME_TRUNCATED)
  end

  def test_rename_user_property_propagates_throughtout_app
    user_property_name = 'developer'
    new_property_name = 'DEV'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate

    card_with_user_property_set = create_card!(:name => 'card for admin', :developer => @admin.id)
    newly_name_property_defintion = edit_property_definition_for(@project, user_property_name, :new_property_name => new_property_name)

    navigate_to_card_list_by_clicking(@project)
    filter_card_list_by(@project, new_property_name => "#{@admin.name}")
    assert_card_present(card_with_user_property_set)
    assert_card_not_present(@card)
    add_column_for(@project, [new_property_name])
    @browser.assert_column_present('cards', new_property_name)
    navigate_to_grid_view_for(@project)
    group_columns_by(new_property_name) # bug 1333
    assert_lane_present(new_property_name, @admin.id)
    open_card(@project, card_with_user_property_set.number)
    set_properties_on_card_show(new_property_name => @team_member.name)
    @browser.run_once_history_generation

    navigate_to_history_for(@project)
    filter_history_using_first_condition_by(@project, new_property_name => "#{@admin.name}")
    assert_history_for(:card, card_with_user_property_set.number).version(1).shows(:set_properties => {new_property_name => "#{@admin.name}"})
    filter_history_using_second_condition_by(@project, new_property_name => "#{@team_member.name}")
    assert_history_for(:card, card_with_user_property_set.number).version(2).shows(:changed => new_property_name, :from => "#{@admin.name}", :to => "#{@team_member.name}")
  end

  def test_add_new_value_inline_not_available_for_user_property_on_card_or_card_type_defaults
    user_property_name = 'tester'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    card_with_user_property_set = create_card!(:name => 'card for admin', :tester => @admin.id)
    open_card(@project, card_with_user_property_set.number)
    assert_inline_enum_value_add_not_present_for(user_property_name, "show")
    open_edit_defaults_page_for(@project, 'Card')
    assert_inline_enum_value_add_not_present_for(user_property_name, "defaults")
  end

  def test_add_new_value_inline_not_available_for_user_property_on_transition
    user_property_name = 'tester'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    assert_inline_value_add_not_present_for_requires_during_transition_create_edit_for(@project, user_property_name)
    assert_inline_value_add_not_present_for_sets_during_transition_create_edit_for(@project, user_property_name)
  end

  def test_can_filter_card_list_by_user_properties
    user_property_name = 'developer'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    card_with_user_property_set = create_card!(:name => 'card for admin', :developer => @admin.id)
    navigate_to_card_list_by_clicking(@project)
    filter_card_list_by(@project, :developer => "#{@admin.name}")
    assert_card_present(card_with_user_property_set)
    assert_card_not_present(@card)
  end

  def test_can_delete_user_property
    user_property_name = "tester and dev"
    create_property_definition_for(@project, user_property_name, :type => 'user')
    setup_property_definitions(:status => ['placeholder'])
    @project.reload.activate
    card_with_user_property_set = create_card!(:name => 'card for admin', user_property_name => @team_member.id)
    delete_property_for(@project, user_property_name)
    assert_notice_message("Property #{user_property_name} has been deleted.")
    assert_property_does_not_exist(user_property_name)
    assert_property_not_present_on_card(@project, card_with_user_property_set, user_property_name)

    navigate_to_card_list_for(@project)
    assert_property_not_present_on_card_list_filter(user_property_name)

    navigate_to_history_for(@project)
    @browser.assert_element_does_not_match('involved_filter_widget', /#{user_property_name}/)
    @browser.assert_element_does_not_match('acquired_filter_widget', /#{user_property_name}/)
  end

  def test_excel_import_cannot_set_user_property_to_non_team_member
    non_existant_user = 'notInMingle'
    non_team_member = users(:existingbob)
    user_property_name = 'dev-QA'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    navigate_to_card_list_by_clicking(@project)

    header_row = ['Number', user_property_name]
    card_data_with_non_existant_user = [['29', non_existant_user]]
    import(excel_copy_string(header_row, card_data_with_non_existant_user), :map => {'dev_qa' => 'as existing property'})
    # bug 1499
    assert_error_message("Error with #{user_property_name} column. Project team does not include #{non_existant_user}. User property values must be set to current team member logins.")
    navigate_to_card_list_by_clicking(@project)

    card_data_with_non_team_member = [['49', non_team_member.login]]
    import(excel_copy_string(header_row, card_data_with_non_team_member), :map => {'dev_qa' => 'as existing property'})
    @browser.assert_text_present "Row 1: Validation failed: #{non_team_member.name} is not a project member"
  end

  # bug 1321
  def test_cannot_create_user_property_without_name
    @project = create_project(:prefix => 'scenario_36_bug1321', :users => [@admin, @team_member])
    create_property_definition_for(@project, '', :description => 'this should fail', :type => 'user')
    assert_error_message("Name can't be blank")
    click_cancel_link
  end

  # bug 1334
  def test_user_property_does_not_show_as_color_by_option
    user_property_name = 'tester'
    card  = create_card!(:name => 'card one')
    create_property_definition_for(@project, user_property_name, :type => 'user')
    navigate_to_card_list_by_clicking(@project)
    switch_to_grid_view
    assert_property_not_present_in_color_by(user_property_name)
  end

  # bug 1421
  def test_creating_user_properties_that_only_differ_by_special_characters_do_not_break_db
    create_property_definition_for(@project, 'foo bar', :type => 'user')
    create_property_definition_for(@project, 'foo_bar', :type => 'user')

    @browser.assert_element_not_present('error')
    @browser.assert_text_not_present('Column name has already been taken')
  end

  # bug 1445
  def test_history_event_displays_user_properties_correctly
    user_property_name = 'Tester'
    card  = create_card!(:name => 'card one')
    create_property_definition_for(@project, user_property_name, :type => 'user')
    open_card(@project, card.number)
    set_properties_on_card_show(user_property_name => @admin.name)
    navigate_to_history_for(@project)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {user_property_name => @admin.name})
  end

  # bug 1454
  def test_cannot_create_property_with_same_name_as_hidden_user_property_and_vice_versa
    status = 'Status'
    setup_property_definitions(:Status => [])
    user_property_name = 'tester'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    hide_property(@project, user_property_name)
    create_property_definition_for(@project, user_property_name)
    assert_error_message('Name has already been taken')

    hide_property(@project, status)
    create_property_definition_for(@project, status, :type => 'user')
    assert_error_message('Name has already been taken')
  end

  def test_can_do_excel_imports_while_there_are_hidden_user_properties
    status = 'status'
    setup_property_definitions(:status => ['new'])
    user_property_name = 'tester'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    hide_property(@project, user_property_name)

    header_row = ['number', 'status']
    card_data = [['32', 'new']]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    assert_notice_message('1 created')
    @browser.assert_element_present('card-number-32')
  end

  # bug 1584
  def test_cannot_set_user_property_to_non_team_member_via_excel_import
    user_property_name = 'dev or tester'
    create_property_definition_for(@project, user_property_name, :type => 'user')

    header_row = ['number', user_property_name]
    card_data = [['456', @non_team_member.login]]
    navigate_to_card_list_for(@project)
    import(excel_copy_string(header_row, card_data))
    assert_error_user_is_not_a_project_member(@non_team_member)
  end

  # bug 1587
  def test_removing_team_member_updates_user_properties_in_existing_saved_views
    cards = create_cards(@project, 3)
    card_one = cards[0]
    user_property_name = 'Owner'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    open_card(@project, card_one.number)
    set_properties_on_card_show(user_property_name => @team_member.name)
    navigate_to_card_list_for(@project, [user_property_name])
    @browser.assert_element_matches('cards', /#{@team_member.name}/)
    remove_from_team_for(@project, @team_member, :update_permanently => true)
    navigate_to_card_list_for(@project, [user_property_name])
    @browser.assert_element_does_not_match('cards', /#{@team_member.name}/)
    navigate_to_history_for(@project)
    assert_history_for(:card, card_one.number).version(3).shows(:unset_properties => {user_property_name => @team_member.name})
  end

  # bug 1479, 1534, 1621, 1625, 1627, 1628
  def test_user_property_values_display_in_case_insensitive_order
    capitalized_team_member = users(:capitalized)
    add_to_team_via_model_for(@project, capitalized_team_member)
    user_property_name = 'project manager'
    user_property_def = create_property_definition_for(@project, user_property_name, :type => 'user')
    navigate_to_grid_view_for(@project)
    group_columns_by(user_property_name)
    # @browser.assert_element_matches('column-selector', /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
    @browser.open("/projects/#{@project.identifier}/cards/grid?group_by=#{user_property_name}&lanes=#{capitalized_team_member.id}%2C#{@admin.id}%2C#{@team_member.id}")

    @browser.open("/projects/#{@project.identifier}/transitions/new")
    @browser.click('show-members')
    @browser.assert_element_matches('member-list', /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
    @browser.click(property_def_with_hidden_requires_drop_link_id(user_property_def.name))
    @browser.assert_element_matches(property_drop_down(user_property_def, 'requires'), /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
    @browser.click(property_def_with_hidden_sets_drop_link_id(user_property_def.name))
    @browser.assert_element_matches(property_drop_down(user_property_def, 'sets'), /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)

    open_card(@project, @card.number)
    @browser.click(droplist_link_id(user_property_def, 'show'))
    @browser.assert_element_matches(droplist_dropdown_id(user_property_def, "show"), /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, 'project manager' => PropertyValue::ANY)
    @browser.click("cards_filter_1_values_drop_link")
    @browser.assert_element_matches("cards_filter_1_values_drop_down", /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
    navigate_to_history_for(@project)
    @browser.click(droplist_link_id(user_property_def))
    @browser.assert_element_matches(droplist_dropdown_id(user_property_def), /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
    @browser.click(droplist_link_id(user_property_def, "acquired"))
    @browser.assert_element_matches(droplist_dropdown_id(user_property_def, "acquired"), /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
    @browser.assert_element_matches("filter_user", /#{@admin.name}.*#{@team_member.name}.*#{capitalized_team_member.name}/m)
  end


  # bug 2129
  def test_setting_user_property_during_card_creation_saves_user_property
    user_property_name = 'tester'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    navigate_to_card_list_for(@project)
    add_card_with_detail_via_quick_add('setting user property')
    set_properties_in_card_edit(user_property_name => @team_member.name)
    save_card
    @browser.wait_for_element_visible 'notice'
    card_number = @project.cards.find_by_name('setting user property').number
    open_card(@project, card_number)
    assert_properties_set_on_card_show(user_property_name => @team_member.name)
    assert_history_for(:card, card_number).version(1).shows(:set_properties => {user_property_name => @team_member.name})
  end

  #bug 2272
  def test_user_properties_dont_have_links_to_an_edit_page_for_them
    user_property_name = 'Reported by'
    user_property = create_property_definition_for(@project, user_property_name, :type => 'user')
    assert_link_not_present("/projects/#{@project.identifier}/enumeration_values/list?definition_id=#{user_property.id}")
  end

  #2441
  def test_current_user_in_link_is_case_insensitive
    user_property_name = 'Owner'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, user_property_name => "#{@admin.name}")
    card = create_card!(:name => 'card with owner set....', :Owner => "#{@admin.id}" )
    set_filter_by_url(@project, "filters[]=[Type][Is][Card]&filters[]=[#{user_property_name}][is][(CURReNT User)]")
    assert_cards_present(card)
  end

  #bug 2362
  def test_can_successfully_set_user_property_values_on_card_show
    user_property_name = 'Assigned To'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    @project.reload.activate
    card = create_card!(:name => 'for testing')
    open_card(@project, card.number)
    set_properties_on_card_show(user_property_name => @team_member.name)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {user_property_name => "#{@team_member.name}"})

    set_properties_on_card_show(user_property_name => NOT_SET)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(3).shows(:changed => user_property_name, :from => @team_member.name, :to => NOT_SET)
  end

  #bug 2507
  def test_update_user_profile_updates_the_saved_view_and_filter_list
    user_property_name = 'Owner'
    create_property_definition_for(@project, user_property_name, :type => 'user')
    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => 'Owner', :value => @admin.name)
    admin_owner = create_card_list_view_for(@project, 'admin')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(admin_owner)
    click_tab(admin_owner)
    assert_selected_value_for_the_filter(1, ADMIN_NAME_TRUNCATED)
    open_edit_profile_for(@admin)
    @browser.type('user_name', "admin user")
    @browser.click_and_wait("link=Save profile")
    navigate_to_project_overview_page(@project)
    click_tab(admin_owner)
    assert_selected_value_for_the_filter(1, "admin user")
  end

  # bug 2893
  def test_removing_team_member_who_is_set_as_user_property_value_on_card_gives_appropriate_warning
    user_property_name = 'owner'
    setup_user_definition(user_property_name)
    card_with_user_property_set = create_card!(:name => 'card with user property set')
    open_card(@project, card_with_user_property_set.number)
    set_properties_on_card_show(user_property_name => @team_member.name)
    remove_from_team_for(@project, @team_member, :update_permanently => false)
    @browser.assert_text_present("Card Properties changed to (not set): #{user_property_name}")
  end

  # bug 2906
  def test_transition_only_setting_user_property_will_be_deleted_when_team_member_is_removed_from_team
    user_property_name = 'owner'
    setup_user_definition(user_property_name)
    @project.reload.activate
    transition_setting_user_property = create_transition_for(@project, 'setting only user property', :set_properties => {user_property_name => @admin.name})
    remove_from_team_for(@project, @admin)
    @browser.assert_text_present("1 Transition Deleted: #{transition_setting_user_property.name}")
    click_continue_to_remove
    assert_user_is_not_team_member(@admin)
    assert_transition_not_present_for(@project, transition_setting_user_property)
  end

  # bug 2906
  def test_transition_requiring_user_property_in_addition_to_other_properties_will_be_deleted_when_team_member_is_removed_from_team
    user_property_name = 'owner'
    status = 'status'
    setup_user_definition(user_property_name)
    setup_property_definitions(status => [])
    @project.reload.activate
    transition_setting_user_property = create_transition_for(@project, 'setting only user property', :set_properties => {user_property_name => @admin.name, status => NOT_SET})
    remove_from_team_for(@project, @admin)
    @browser.assert_text_present("1 Transition Deleted: #{transition_setting_user_property.name}")
    click_continue_to_remove
    assert_user_is_not_team_member(@admin)
    assert_transition_not_present_for(@project, transition_setting_user_property)
  end

  # bug 2906
  def test_transition_requiring_user_property_will_be_deleted_when_team_member_is_removed_from_team
    user_property_name = 'owner'
    status = 'status'
    setup_user_definition(user_property_name)
    setup_property_definitions(status => [])
    @project.reload.activate
    transition_requiring_user_property = create_transition_for(@project, 'requiring user property', :required_properties => {user_property_name => @admin.name}, :set_properties => {status => NOT_SET})
    remove_from_team_for(@project, @admin)
    @browser.assert_text_present("1 Transition Deleted: #{transition_requiring_user_property.name}")
    click_continue_to_remove
    assert_user_is_not_team_member(@admin)
    assert_transition_not_present_for(@project, transition_requiring_user_property)
  end

  # bug 3368, bug 5051
  def test_invoking_transition_that_sets_current_user_when_logged_in_user_is_not_team_member_gives_error_message
    user_property_name = 'owner'
    current_user = '(current user)'
    setup_user_definition(user_property_name)
    card = create_card!(:name => 'for testing')
    @project.reload.activate
    transition = create_transition_for(@project, 'setting current user', :type => 'Card', :set_properties => {user_property_name => current_user})
    remove_from_team_for(@project, @admin)
    open_card(@project, card)
    click_transition_link_on_card(transition)
    assert_error_user_is_not_a_project_member(@admin)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(card)
    execute_bulk_transition_action(transition)
    assert_error_user_is_not_a_project_member(@admin)
    @browser.assert_text_not_present("Setting Current User successfully applied to card")
  end

  # bug 1390
  def test_removing_team_member_from_project_also_removes_them_from_transitions_to_which_they_are_assigned
    transition_originally_assigned_to_one_team_member = create_transition_for(@project, 'for single team member', :set_properties => {STATUS => OPEN}, :for_team_members => [@team_member])
    new_card = create_card!(:name => 'plain card', STATUS => NEW)

    remove_from_team_for(@project, @team_member)
    @browser.assert_text_present("1 Transition Modified: #{transition_originally_assigned_to_one_team_member.name}")
    click_continue_to_remove
    open_transition_for_edit(@project, transition_originally_assigned_to_one_team_member)
    assert_user_not_present_for_transition_assignment(@team_member)
    navigate_to_transition_management_for(@project)
    assert_transition_not_assigned_to(@team_member, transition_originally_assigned_to_one_team_member)
    assert_transition_assigned_to_all_team_members(transition_originally_assigned_to_one_team_member)
  end

  # bug 1390
  def test_removing_team_member_from_project_also_removes_only_them_from_transition_to_which_multiple_team_members_are_assigned
    transition_originally_assigned_to_multiple_team_members = create_transition_for(@project, 'for multiple team members', :set_properties => {STATUS => OPEN}, :for_team_members => [@team_member, @admin])
    new_card = create_card!(:name => 'plain card', STATUS => NEW)

    remove_from_team_for(@project, @team_member)
    @browser.assert_text_present("1 Transition Modified: #{transition_originally_assigned_to_multiple_team_members.name}")
    click_continue_to_remove
    open_transition_for_edit(@project, transition_originally_assigned_to_multiple_team_members)
    assert_user_not_present_for_transition_assignment(@team_member)

    assert_user_not_present_for_transition_assignment(@team_member)
    assert_team_member_assigned_to_transition(@admin)
    navigate_to_transition_management_for(@project)
    assert_transition_not_assigned_to(@team_member, transition_originally_assigned_to_multiple_team_members)
    assert_transition_assigned_to(@admin, transition_originally_assigned_to_multiple_team_members)
  end


  # bug 3990.
  def test_should_stay_on_tree_when_invoking_transition_that_sets_current_user_when_user_is_not_a_team_member
    owner = setup_user_definition(OWNER)
    type_release = setup_card_type(@project, RELEASE)
    type_iteration = setup_card_type(@project, 'iteration')
    type_story = setup_card_type(@project, 'story')
    type_release.add_property_definition owner
    tree = setup_tree(@project, PLANNING_TREE, :types => [type_release, type_iteration, type_story], :relationship_names => ['pt - release', 'pt - iteration'])

    login_as_admin_not_on_team
    transition_set_current_user = create_transition_for(@project, 'setting current user', :type => RELEASE, :set_properties => {OWNER => CURRENT_USER})
    card_for_transitioning = create_card!(:name => 'test card', :card_type => RELEASE)
    add_card_to_tree(tree, card_for_transitioning)
    navigate_to_grid_view_for(@project, :tree_name => PLANNING_TREE)
    click_on_transition_for_card_in_grid_view(card_for_transitioning, transition_set_current_user)
    assert_tree_selected(tree.name)
  end

  #bug 1380
  def test_user_property_sets_on_card_when_dragged_in_grid_view_grouped_by_user_property
    owner_property_definition = setup_user_definition(OWNER)
    @admin_card = create_card!(:name => 'card to be dragged', OWNER => @admin.id)
    @teammember_card = create_card!(:name => 'card stay where it is', OWNER => @team_member.id)

    navigate_to_grid_view_for(@project,:group_by => OWNER)
    drag_and_drop_card_from_lane(@admin_card.html_id, OWNER, @team_member.id)
    open_card(@project,@admin_card)
    assert_history_for(:card, @admin_card.number).version(2).shows(:changed => owner_property_definition.name, :from => @admin.name, :to => @team_member.name)
  end
end
