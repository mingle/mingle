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

# Tags: relationship-properties, tree-usage, card-list, tree-filters
class Scenario85UsingRelationshipPropertiesInCardFiltersTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  
  TYPE = 'Type'
  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  USER_PROPERTY = 'owner'
  DATE_PROPERTY = 'closedOn'
  FREE_TEXT_PROPERTY = 'resolution'
  SIZE = 'Size'
  BLANK = ''
  NOT_SET = '(not set)'
  
  PLANNING_TREE = 'Planning Tree'
  RELEASE_PROPERTY = 'Planning Tree release'
  ITERATION_PROPERTY = 'Planning Tree iteration'
  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_85', :admins => [@project_admin], :users => [@project_member])
    setup_property_definitions(STATUS => [NEW, OPEN])
    setup_user_definition(USER_PROPERTY)
    setup_text_property_definition(FREE_TEXT_PROPERTY)
    setup_date_property_definition(DATE_PROPERTY)
    setup_numeric_property_definition(SIZE, [2, 4])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, SIZE, FREE_TEXT_PROPERTY, USER_PROPERTY, DATE_PROPERTY])
    @type_iteration = setup_card_type(@project, ITERATION, :properties => [STATUS])
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
    add_card_to_tree(@planning_tree, @release1)
  end
  
  # bug 3280
  def test_cards_matching_relationship_property_type_and_currently_in_tree_appear_as_possible_filter_value_in_relationship_property_card_selector
    navigate_to_card_list_for(@project)
    set_the_filter_value_option(0, ITERATION)
    add_new_filter
    set_the_filter_property_option(1, RELEASE_PROPERTY)
    open_filter_values_widget_for_relationship_property(1)
    
    @browser.assert_element_present(card_selector_result_locator(:filter, @release1.number))
    [@release2, @iteration1, @iteration2, @story1].each do |card|
      @browser.assert_element_not_present(card_selector_result_locator(:filter, card.number))
    end
  end
  
  # bug 3399
  def test_tabbed_view_filtered_by_relationship_property_does_not_show_value_card_number_twice
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => ITERATION, RELEASE_PROPERTY => card_number_and_name(@release1))
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    switch_to_grid_view
    group_columns_by(STATUS)
    view_name = 'grid view with relationship property filter'
    create_card_list_view_for(@project, view_name)
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_view_named(view_name)
    click_tab(view_name)
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    assert_value_not_selected_for_the_filter(1, "#{@release1.number} #{RELEASE_PROPERTY}")
    assert_value_not_selected_for_the_filter(1, "#{@release1.number} #{@release1.number}")
    assert_value_not_selected_for_the_filter(1, "#{RELEASE_PROPERTY}")
  end  
  
  # bug 3412
  def test_value_for_relationship_property_escapes_html_in_card_selector_lightbox
    card_name_with_html_tags = "<b>NEW</b> card"
    release_card = create_card!(:name => card_name_with_html_tags, :card_type => @type_release)
    add_card_to_tree(@planning_tree, release_card)
    navigate_to_card_list_for(@project)
    click_add_a_filter_link
    filter_card_list_by(@project, :type => ITERATION)
    open_relationship_property_card_selector_in_filter_for(RELEASE_PROPERTY)
    @browser.assert_text(card_selector_result_locator(:filter, release_card.number), "##{release_card.number} #{card_name_with_html_tags}")
  end
  
  def open_relationship_property_card_selector_in_filter_for(property_name)
    @browser.click "cards_filter_1_properties_drop_link"
    @browser.click "cards_filter_1_properties_option_#{property_name}"
    open_filter_values_widget_for_relationship_property(1)
  end
  
  # bug 3413
  def test_relationship_property_filters_do_not_show_property_name_as_its_filter_value_after_page_reload_caused_by_group_by
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => ITERATION, RELEASE_PROPERTY => card_number_and_name(@release1))
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    switch_to_grid_view
    group_columns_by(STATUS)
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    assert_value_not_selected_for_the_filter(1, "#{@release1.number} #{RELEASE_PROPERTY}")
    assert_value_not_selected_for_the_filter(1, "#{RELEASE_PROPERTY}")
  end
  
  # bug 3435
  def test_relationship_property_filters_do_not_show_property_name_as_its_filter_value_after_page_reload_caused_by_switching_tabs
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => ITERATION, RELEASE_PROPERTY => card_number_and_name(@release1))
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    saved_view = create_card_list_view_for(@project, 'release view')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(saved_view)
    navigate_to_saved_view(saved_view.name)
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    assert_value_not_selected_for_the_filter(1, "#{@release1.number} #{RELEASE_PROPERTY}")
    assert_value_not_selected_for_the_filter(1, "#{RELEASE_PROPERTY}")
    click_all_tab
    navigate_to_saved_view(saved_view.name)
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    assert_value_not_selected_for_the_filter(1, "#{@release1.number} #{RELEASE_PROPERTY}")
    assert_value_not_selected_for_the_filter(1, "#{RELEASE_PROPERTY}")
  end
  
  # bug 3385
  def test_relationship_property_filters_do_not_show_property_name_as_its_filter_value_after_page_reload_caused_by_clicking_link_to_this_page
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => ITERATION, RELEASE_PROPERTY => card_number_and_name(@release1))
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    assert_value_not_selected_for_the_filter(1, "#{@release1.number} #{RELEASE_PROPERTY}")
    assert_value_not_selected_for_the_filter(1, "#{RELEASE_PROPERTY}")
    click_link_to_this_page
    assert_selected_value_for_the_filter(1, card_number_and_name(@release1))
    assert_value_not_selected_for_the_filter(1, "#{@release1.number} #{RELEASE_PROPERTY}")
    assert_value_not_selected_for_the_filter(1, "#{RELEASE_PROPERTY}")
  end
  
  # bug 3431
  def test_invaid_data_entered_in_url_when_filtering_by_plv_gives_invalid_error_message_and_not_were_sorry_page
    numeric_plv = setup_project_variable(@project, :name => 'numeric plv', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '1000', :properties => [SIZE])
    user_plv = setup_project_variable(@project, :name => 'user plv', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @project_member, :properties => [USER_PROPERTY])
    navigate_to_card_list_for(@project)
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{USER_PROPERTY}][is][#{plv_display_name(numeric_plv)}]")
    assert_selected_value_for_the_filter(1, plv_display_name(numeric_plv))
    @browser.assert_text_present("Filter is invalid.")
    @browser.assert_text_present("Project variable #{plv_display_name(numeric_plv)} is not valid for the property #{USER_PROPERTY}.")
  end
  
  # bug 3502
  def test_can_create_view_filtered_by_date_plv_that_has_value_that_is_in_different_date_format_than_the_project
    project_variable_value_in_default_project_date_format = '01 Apr 2008'
    card_with_date_set = create_card!(:name => 'card with date set', :card_type => STORY, DATE_PROPERTY => project_variable_value_in_default_project_date_format)
    card_with_date_not_set = create_card!(:name => 'card without date set', :card_type => STORY)
    project_variable = create_project_variable(@project, :name => 'date plv', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => project_variable_value_in_default_project_date_format, :properties => [DATE_PROPERTY])
    open_project_admin_for(@project)
    set_project_date_format('yyyy/mm/dd')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, DATE_PROPERTY => plv_display_name(project_variable))
    assert_selected_value_for_the_filter(1, plv_display_name(project_variable))
    @browser.assert_text_not_present("Filter is invalid.")
    @browser.assert_text_not_present("Property #{DATE_PROPERTY} #{plv_display_name(project_variable)} is an invalid date.")
    assert_card_present(card_with_date_set)
    assert_card_not_present(card_with_date_not_set)
  end
end
