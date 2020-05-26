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

# Tags: scenario, properties, transition
class Scenario57HiddenPropertiesTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  
  CARD = 'Card'
  STORY = 'story'
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  PRIORITY = 'priority'
  HIGH = 'high'
  LOW = 'low'
  SIZE = 'size'
  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'
  VALID_DATE_VALUE = '12 Apr 1943'
  BLANK = ''
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session    
    @admin = users(:admin)
    @read_only_user = users(:read_only_user)
    @project_member = users(:project_member)
    @project_admin = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_57', :admins => [@project_admin], :users => [@admin,@project_member],:read_only_users => [@read_only_user],:anonymous_accessible => true)
    setup_property_definitions(STATUS => [NEW, OPEN], PRIORITY => [HIGH, LOW])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    setup_numeric_property_definition(SIZE, [2, 4])
    login_as_proj_admin_user
  end
  
  def test_should_not_show_toggle_hidden_properties_checkbox_when_there_are_no_hidden_propertiew_for_card
    hide_property(@project, PRIORITY)
    story = setup_card_type(@project, STORY, :properties => [STATUS])
    story_1 = create_card!(:name => 'the first story',:card_type => STORY)
    open_card(@project, story_1.number)
    assert_toggle_hidden_properties_checkbox_not_present
    
    set_card_type_on_card_show(CARD)
    assert_toggle_hidden_properties_checkbox_present
    set_card_type_on_card_show(STORY)
    assert_toggle_hidden_properties_checkbox_not_present    
  end

  def test_should_remember_status_of_hidden_properties_checkbox_in_session
    card_1 = create_card!(:name => 'the first card')
    card_2 = create_card!(:name => 'the second card')
    hide_property(@project, PRIORITY)
    navigate_to_card_list_for(@project)
    add_column_for(@project, [STATUS])
    saved_view = create_card_list_view_for(@project, 'a sample favorite')

    open_card(@project, card_1.number)
    ensure_hidden_properties_visible
    open_card(@project, card_2.number)
    assert_toggle_hidden_properties_checkbox_checked
    set_property_value_on_card_show(@project,STATUS,NEW)
    assert_toggle_hidden_properties_checkbox_checked
    add_comment('comment the second card')
    assert_toggle_hidden_properties_checkbox_checked
    click_edit_link_on_card
    assert_toggle_hidden_properties_checkbox_checked
    open_card(@project, card_2.number)
    assert_toggle_hidden_properties_checkbox_checked    
    navigate_to_saved_view(saved_view.name)
    open_card(@project, card_1.number)
    assert_toggle_hidden_properties_checkbox_checked
    logout

    login_as_proj_admin_user
    open_card(@project, card_2.number)
    assert_toggle_hidden_properties_checkbox_unchecked
  end

  def test_admin_and_full_team_member_can_toggle_hidden_properties_checkbox
    card = create_card!(:name => 'testing toggle hidden properties checkbox')
    hide_property(@project, PRIORITY)

    open_card(@project, card.number)
    ensure_hidden_properties_visible
    set_property_value_on_card_show(@project,PRIORITY,HIGH)
    assert_property_set_on_card_show(PRIORITY, HIGH)
    click_edit_link_on_card
    set_properties_in_card_edit(PRIORITY => LOW)
    assert_properties_set_on_card_edit(PRIORITY => LOW)
    logout

    as_project_member do
      open_card(@project, card.number)
      ensure_hidden_properties_visible
      assert_property_set_on_card_show(PRIORITY, HIGH)
      assert_properties_not_editable_on_card_show([PRIORITY])
      click_edit_link_on_card
      assert_property_not_editable_on_card_edit(PRIORITY)
    end
  end
  
  def test_read_only_and_anon_user_should_not_see_the_toggle_hidden_properties_checkbox
    card = create_card!(:name => 'testing toggle hidden properties checkbox')
    hide_property(@project, PRIORITY)
    register_license_that_allows_anonymous_users
    
    logout
    open_card(@project, card.number)
    assert_toggle_hidden_properties_checkbox_not_present
    assert_property_not_present_on_card_show(PRIORITY)
    
    login_as_read_only_user
    open_card(@project, card.number)
    assert_toggle_hidden_properties_checkbox_not_present
    assert_property_not_present_on_card_show(PRIORITY)
  end
  
  
  def test_show_hidden_properties_in_card_show_or_edit
    card = create_card!(:name => 'testing hidden properties')
    hide_property(@project, PRIORITY)
    hide_property(@project, DATE_PROPERTY)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)

    priority = @project.find_property_definition_or_nil(PRIORITY, :with_hidden => true) unless PRIORITY.respond_to?(:name)
    date_property = @project.find_property_definition_or_nil(DATE_PROPERTY, :with_hidden => true) unless DATE_PROPERTY.respond_to?(:name)
    free_text_property = @project.find_property_definition_or_nil(FREE_TEXT_PROPERTY, :with_hidden => true) unless FREE_TEXT_PROPERTY.respond_to?(:name)
    user_property = @project.find_property_definition_or_nil(USER_PROPERTY, :with_hidden => true) unless USER_PROPERTY.respond_to?(:name)    

    log_back_in "proj_admin"
    open_card(@project, card.number)
    assert_toggle_hidden_properties_checkbox_unchecked    

    assert_property_not_present_on_card_show(PRIORITY)
    assert_property_not_present_on_card_show(DATE_PROPERTY)
    assert_property_not_present_on_card_show(FREE_TEXT_PROPERTY)
    assert_property_not_present_on_card_show(USER_PROPERTY)
    click_edit_link_on_card
    assert_property_not_present_on_card_edit(PRIORITY)
    assert_property_not_present_on_card_edit(DATE_PROPERTY)
    assert_property_not_present_on_card_edit(FREE_TEXT_PROPERTY)
    assert_property_not_present_on_card_edit(USER_PROPERTY)

    ensure_hidden_properties_visible
    assert_toggle_hidden_properties_checkbox_checked

    assert_property_is_visible_on_card_edit(priority)
    assert_property_is_visible_on_card_edit(date_property)
    assert_property_is_visible_on_card_edit(free_text_property)
    assert_property_is_visible_on_card_edit(user_property)

    open_card(@project, card.number)
    assert_property_present_on_card_show(PRIORITY)
    assert_property_present_on_card_show(DATE_PROPERTY)
    assert_property_present_on_card_show(FREE_TEXT_PROPERTY)
    assert_property_present_on_card_show(USER_PROPERTY)
  end
  
  def test_properties_associated_to_card_types_are_still_visible_on_card_type_edit_page_after_they_are_hidden
    setup_card_type(@project, STORY, :properties => [STATUS, USER_PROPERTY, DATE_PROPERTY])
    hide_property(@project, STATUS)
    hide_property(@project, USER_PROPERTY)
    open_edit_card_type_page(@project, STORY)
    assert_properties_selected_for_card_type(@project, STATUS, USER_PROPERTY)
  end
  
  #bug 1458
  def test_existing_transitions_maintain_property_even_after_it_is_hidden
    transition_setting_hidden_property = create_transition_for(@project, 'setting hidden', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => OPEN})
    hide_property(@project, STATUS)
    navigate_to_transition_management_for(@project)
    open_transition_for_edit(@project, transition_setting_hidden_property)
    assert_requires_property_present(STATUS)
    assert_sets_property_present(STATUS)
  end
  
  # bug 2509
  def test_transition_can_set_values_of_hidden_properties
    transition_setting_hidden_property = create_transition_for(@project, 'setting hidden', :required_properties => {STATUS => NEW}, :set_properties => {STATUS => OPEN, PRIORITY => LOW})
    card = create_card!(:name => 'plain card', STATUS => NEW)
    hide_property(@project, PRIORITY)
    open_card(@project, card.number)
    click_transition_link_on_card(transition_setting_hidden_property)
    @browser.run_once_history_generation
    open_card(@project, card.number)
    assert_history_for(:card, card.number).version(2).shows(:set_properties => {PRIORITY => LOW})
    assert_history_for(:card, card.number).version(2).shows(:changed => STATUS, :from => NEW, :to => OPEN)
  end
 
  def test_hidden_properties_are_available_in_transition_editor
    hide_property(@project, STATUS)
    hide_property(@project, DATE_PROPERTY)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)
    navigate_to_transition_management_for(@project)
    click_create_new_transition_link
    assert_requires_property_present(STATUS)
    assert_requires_property_present(DATE_PROPERTY)
    assert_requires_property_present(FREE_TEXT_PROPERTY)
    assert_requires_property_present(USER_PROPERTY)
    assert_sets_property_present(STATUS)
    assert_sets_property_present(DATE_PROPERTY)
    assert_sets_property_present(FREE_TEXT_PROPERTY)
    assert_sets_property_present(USER_PROPERTY)
  end
  
  def test_hidden_properties_not_present_in_bulk_edit_properties
    card = create_card!(:name => 'testing hidden properties')
    hide_property(@project, PRIORITY)
    hide_property(@project, DATE_PROPERTY)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)
    navigate_to_card_list_for(@project)
    select_all
    click_edit_properties_button
    assert_property_not_present_in_bulk_edit_panel(PRIORITY)
    assert_property_not_present_in_bulk_edit_panel(DATE_PROPERTY)
    assert_property_not_present_in_bulk_edit_panel(FREE_TEXT_PROPERTY)
    assert_property_not_present_in_bulk_edit_panel(USER_PROPERTY)
  end
  
  def test_hidden_properties_do_not_appear_in_card_list_filters_or_column_selector
    card = create_card!(:name => 'testing hidden properties')
    hide_property(@project, PRIORITY)
    hide_property(@project, DATE_PROPERTY)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)
    navigate_to_card_list_for(@project)
    assert_property_not_present_on_card_list_filter(PRIORITY)
    assert_property_not_present_on_card_list_filter(DATE_PROPERTY)
    assert_property_not_present_on_card_list_filter(FREE_TEXT_PROPERTY)
    assert_property_not_present_on_card_list_filter(USER_PROPERTY)
    assert_properties_not_present_on_add_remove_column_dropdown(@project, [PRIORITY, DATE_PROPERTY, FREE_TEXT_PROPERTY, USER_PROPERTY])
  end
  
  def test_hidden_properties_do_not_appear_on_grid_view_group_by_or_order_by_or_filters
    card = create_card!(:name => 'testing hidden properties')
    hide_property(@project, PRIORITY)
    hide_property(@project, DATE_PROPERTY)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)
    navigate_to_card_list_for(@project)
    switch_to_grid_view
    assert_property_not_present_in_group_columns_by(PRIORITY)
    assert_property_not_present_in_group_columns_by(DATE_PROPERTY)
    assert_property_not_present_in_group_columns_by(FREE_TEXT_PROPERTY)
    assert_property_not_present_in_group_columns_by(USER_PROPERTY)
    
    assert_property_not_present_in_color_by(PRIORITY)
    assert_property_not_present_in_color_by(DATE_PROPERTY)
    assert_property_not_present_in_color_by(FREE_TEXT_PROPERTY)
    assert_property_not_present_in_color_by(USER_PROPERTY)
    
    assert_property_not_present_on_card_list_filter(PRIORITY)
    assert_property_not_present_on_card_list_filter(DATE_PROPERTY)
    assert_property_not_present_on_card_list_filter(FREE_TEXT_PROPERTY)
    assert_property_not_present_on_card_list_filter(USER_PROPERTY)
  end
  
  def test_hidden_properties_can_be_set_and_updated_via_excel_import
    initial_valid_date = '01 Apr 2007'
    initial_text_value = '1st try'
    existing_card = create_card!(:name => 'existing card', PRIORITY => LOW, DATE_PROPERTY => initial_valid_date, FREE_TEXT_PROPERTY => initial_text_value, USER_PROPERTY => @admin.id)
    new_card_number = 76
    value_for_free_text = 'some text'
    hide_property(@project, PRIORITY)
    hide_property(@project, DATE_PROPERTY)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)
    navigate_to_card_list_for(@project)
    
    header_row = ['Number', PRIORITY, DATE_PROPERTY, FREE_TEXT_PROPERTY, USER_PROPERTY]
    card_data = [
      [existing_card.number, HIGH, VALID_DATE_VALUE, value_for_free_text, @project_admin.login],
      [new_card_number, LOW, VALID_DATE_VALUE, value_for_free_text, @admin.login]
    ]
    import(excel_copy_string(header_row, card_data))
    assert_import_complete_with(:rows  => 2, :rows_created  => 1, :rows_updated => 1)
    @browser.run_once_history_generation
    open_card(@project, existing_card.number)
    assert_history_for(:card, existing_card.number).version(2).shows(:changed => PRIORITY, :from => LOW, :to => HIGH)
    assert_history_for(:card, existing_card.number).version(2).shows(:changed => DATE_PROPERTY, :from => initial_valid_date, :to => VALID_DATE_VALUE)
    assert_history_for(:card, existing_card.number).version(2).shows(:changed => FREE_TEXT_PROPERTY, :from => initial_text_value, :to => value_for_free_text)
    assert_history_for(:card, existing_card.number).version(2).shows(:changed => USER_PROPERTY, :from => @admin.name, :to => @project_admin.name)
    open_card(@project, new_card_number)
    assert_history_for(:card, new_card_number).version(1).shows(:set_properties => {PRIORITY => LOW, DATE_PROPERTY => VALID_DATE_VALUE, FREE_TEXT_PROPERTY => value_for_free_text, USER_PROPERTY => @admin.login})
  end
  
  # there may eventually be a way to view hidden properties in the history filters in the future, but for now this is how it should work
  def test_hidden_properties_do_not_appear_in_history_filters
    hide_property(@project, PRIORITY)
    hide_property(@project, DATE_PROPERTY)
    hide_property(@project, FREE_TEXT_PROPERTY)
    hide_property(@project, USER_PROPERTY)
    navigate_to_history_for(@project)
    assert_property_not_present_in_first_filter_widget(PRIORITY)
    assert_property_not_present_in_first_filter_widget(DATE_PROPERTY)
    assert_property_not_present_in_first_filter_widget(FREE_TEXT_PROPERTY)
    assert_property_not_present_in_first_filter_widget(USER_PROPERTY)
    assert_property_not_present_in_second_filter_widget(PRIORITY)
    assert_property_not_present_in_second_filter_widget(DATE_PROPERTY)
    assert_property_not_present_in_second_filter_widget(FREE_TEXT_PROPERTY)   
    assert_property_not_present_in_second_filter_widget(USER_PROPERTY)
  end
  
  def test_hiding_properties_deletes_related_saved_and_tabbed_views
    filter_type_card = "filters[]=[Type][is][Card]"
    filter_priority_is_high = "&filters[]=[#{PRIORITY}][is][#{HIGH}]"
    set_filter_by_url(@project, filter_type_card + filter_priority_is_high)
    priority_high_view = create_card_list_view_for(@project, 'priority high view')
    hide_property(@project, PRIORITY)
    assert_notice_message("Property #{PRIORITY} is now hidden. The following favorites have been deleted: #{priority_high_view.name}.")
    
    filter_by_date = "&filters[]=[#{DATE_PROPERTY}][is][#{VALID_DATE_VALUE}]"
    set_filter_by_url(@project, filter_type_card + filter_by_date)
    date_property_filter_view = create_card_list_view_for(@project, 'date view')
    hide_property(@project, DATE_PROPERTY)
    assert_notice_message("Property #{DATE_PROPERTY} is now hidden. The following favorites have been deleted: #{date_property_filter_view.name}.")
    
    filter_by_user = "&filters[]=[#{USER_PROPERTY}][is][#{@admin.login}]"
    set_filter_by_url(@project, filter_type_card + filter_by_user)
    user_property_filter_view = create_card_list_view_for(@project, 'user property view')
    hide_property(@project, USER_PROPERTY)
    assert_notice_message("Property #{USER_PROPERTY} is now hidden. The following favorites have been deleted: #{user_property_filter_view.name}.")
  end
  
  # bug 2974
  def test_hidden_properties_can_be_used_in_pivot_table_colums_and_rows
    new_card = create_card!(:name => 'new card', STATUS => NEW)
    open_high_card = create_card!(:name => 'open high card', STATUS => NEW, PRIORITY => HIGH)
    card_with_no_properties_set = create_card!(:name => 'no properties set')
    open_project(@project)
    hide_property(@project, STATUS)
    hide_property(@project, PRIORITY)
    edit_overview_page
    pivot_table_using_hidden_status_property = add_pivot_table_query_and_save_for(STATUS, PRIORITY, :conditions => "Type = CARD", :empty_rows => 'true', :empty_columns => 'true', :totals => 'true')
    @browser.assert_text_not_present('Error in pivot-table macro')
    @browser.assert_text_not_present("No such property: #{STATUS}")
    @browser.assert_text_not_present("No such property: #{PRIORITY}")
    assert_table_row_data_for(pivot_table_using_hidden_status_property, :row_number => 1, :cell_values => ['1', BLANK, '1'])
    assert_table_row_data_for(pivot_table_using_hidden_status_property, :row_number => 2, :cell_values => [BLANK, BLANK, BLANK])
    assert_table_row_data_for(pivot_table_using_hidden_status_property, :row_number => 3, :cell_values => [BLANK, BLANK, '1'])
    assert_table_row_data_for(pivot_table_using_hidden_status_property, :row_number => 4, :cell_values => ['1', BLANK, '2'])
  end
  
  # bug 2974
  def test_hidden_properties_can_be_used_in_pivot_table_aggregates
    new_card = create_card!(:name => 'new card', STATUS => NEW)
    open_high_card = create_card!(:name => 'open high card', STATUS => NEW, PRIORITY => HIGH, SIZE => 4)
    card_with_no_properties_set = create_card!(:name => 'no properties set')
    open_project(@project)
    
    page_name = 'foo'
    create_new_wiki_page(@project, page_name, 'place holder text')
    hide_property(@project, SIZE)
    open_wiki_page_for_edit(@project, page_name)
    pivot_table_using_hidden_size_property = add_pivot_table_query_and_save_for(STATUS, PRIORITY, :conditions => "Type = CARD", :aggregation => "SUM(#{SIZE})", :empty_rows => 'true', :empty_columns => 'true', :totals => 'true')
    @browser.assert_text_not_present('Error in pivot-table macro')
    @browser.assert_text_not_present("No such property: #{SIZE}")
    assert_table_row_data_for(pivot_table_using_hidden_size_property, :row_number => 1, :cell_values => ['4', BLANK, '0'])
  end
end
