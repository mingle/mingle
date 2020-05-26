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

#Tags:  card-properties, #4405
class Scenario110CardTypePropertyCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'
  DEPENDENCY = 'dependency'
  CARD = 'Card'

  STORY = 'Story'
  DEFECT = 'Defect'

  NOTSET = '(not set)'
  SIMPLE_TREE = 'simple tree'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_110', :users => [@non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(PRIORITY => ['high', 'low'], STATUS => ['new',  'close', 'open'])
    @story_type = setup_card_type(@project, STORY, :properties => [PRIORITY])
    @defect_type = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS])
    login_as_proj_admin_user
    @card_1 = create_card!(:name => 'sample card_1', :card_type => STORY, PRIORITY => 'high')
    @tree = create_and_configure_new_card_tree(@project, :name => SIMPLE_TREE, :types => [STORY, DEFECT], :relationship_names => ["tree-#{STORY}"])
    navigate_to_property_management_page_for(@project)
  end

  def test_can_create_card_properties_on_property_management_page
    navigate_to_property_management_page_for(@project)
    click_create_new_card_property
    @browser.assert_element_present('definition_type_card_relationship')
    @browser.click('definition_type_card_relationship')
    type_property_name("card property")
    click_create_property
    assert_notice_message("Property was successfully created.")
  end

  # bug 7781
  def test_should_be_able_to_remove_a_property_from_card_type_A_even_though_card_type_B_is_using_it_in_a_favorite
    property_for_A_and_B = 'property_for_A_and_B'
    setup_property_definitions(property_for_A_and_B => ['A', 'B'])
    card_type_A = setup_card_type(@project, "Type A", :properties => [property_for_A_and_B])
    card_type_A = setup_card_type(@project, "Type B", :properties => [property_for_A_and_B])
    navigate_to_card_list_for(@project)
    set_the_filter_value_option(0, "Type A")
    add_new_filter
    set_the_filter_property_option(1, property_for_A_and_B)
    set_the_filter_value_option(1, 'A')
    navigate_to_property_management_page_for(@project)
    edit_property_definition_for(@project, property_for_A_and_B, :card_types_to_uncheck =>["Type B"])
    assert_notice_message("Property was successfully updated.")
  end

  def test_cannot_create_card_property_with_names_used_already_or_invalid_or_predefined_name
    predefined_properties = ['number', 'name', 'description', 'type', 'created by', 'modified by']
    variations_of_modified_by = ['modified-by', 'modified_by', 'modified:by']
    variations_of_created_by = ['created_by', 'created_by', 'created.by']
    invalid_properties = ['fsdf[', 'sdfsd]', 'dsf=', '&sdfs', 'safs#']
    taken_names = ["tree-#{STORY}", PRIORITY]
    predefined_properties = predefined_properties + variations_of_created_by + variations_of_modified_by
    predefined_properties.each {|predefined_property| assert_card_property_not_created(predefined_property)}
    # predefined_properties.each {|predefined_property| assert_card_property_not_created(predefined_property.capitalize)}
    # predefined_properties.each {|predefined_property| assert_card_property_not_created(predefined_property.upcase)}
    invalid_properties.each {|invalid_property| assert_card_property_not_created(invalid_property, 'Name should not contain')}
    taken_names.each {|taken_names| assert_card_property_not_created(taken_names, 'Name has already been taken')}
  end

  def test_can_not_lock_but_can_hide_and_make_transition_only_on_card_propety
    card_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD)
    assert_hide_check_box_enabled_for(@project, card_property)
    assert_transition_only_check_box_enabled(@project, card_property)
    assert_lock_check_box_not_applicable(@project, card_property)
  end

  def test_usage_of_card_property_after_been_created
    card_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD, :types => [STORY])
    # property management page
    navigate_to_property_management_page_for(@project)
    assert_property_exists(card_property)
    # card defaults
    open_edit_defaults_page_for(@project, STORY)
    assert_property_present_on_card_defaults(DEPENDENCY)
    open_edit_defaults_page_for(@project, DEFECT)
    assert_property_not_present_on_card_defaults(DEFECT)
    # transiton create page
    open_transition_create_page @project
    assert_requires_property_not_present DEPENDENCY
    assert_sets_property_not_present DEPENDENCY
    set_card_type_on_transitions_page(STORY)
    assert_requires_property_present DEPENDENCY
    assert_sets_property_present DEPENDENCY
    # card show card edit
    card_2 = create_card!(:name => 'sample card_2', :card_type => DEFECT)
    open_card(@project, @card_1)
    assert_property_present_on_card_show(card_property)
    click_edit_link_on_card
    assert_property_is_visible_on_card_edit(card_property)
    open_card(@project, card_2)
    assert_property_not_present_on_card_show(card_property)
    click_edit_link_on_card
    assert_property_not_present_on_card_edit(card_property)
    # list view, grid view
    navigate_to_view_for(@project, 'list')
    check_cards_in_list_view(@card_1)
    click_edit_properties_button
    @browser.assert_element_present("bulk_cardrelationshippropertydefinition_#{card_property.id}_label")
    assert_properties_present_on_add_remove_column_dropdown(@project, [card_property])
    navigate_to_view_for(@project, 'grid')
    set_the_filter_value_option(0, STORY)
    add_new_filter
    assert_filter_property_present_on(1, :properties => [DEPENDENCY])
    assert_property_not_present_in_group_columns_by(DEPENDENCY)
    # tree view
    navigate_to_tree_view_for(@project, SIMPLE_TREE)
    add_new_tree_filter_for(@story_type)
    open_tree_filter_property_list(@story_type, 0)
    assert_filter_property_available(@story_type, 0, DEPENDENCY)
  end

  def test_update_of_card_property_after_been_renamed
    card_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD, :types => [STORY])
    have_cards_type_default_transitons_prepared_for_test_card_property_changes
    have_saved_views_prepared_for_test_card_property_changes

    new_property_name = 'new dependency'
    edit_property_definition_for(@project, card_property.name, :new_property_name => new_property_name)
    assert_notice_message("Property was successfully updated.")
    new_card_property = @project.find_property_definition_or_nil(new_property_name, :with_hidden => true)
    # card default
    open_edit_defaults_page_for(@project, STORY)
    assert_property_present_on_card_defaults(new_property_name)
    #  transition
    open_transition_for_edit(@project, @transition.name)
    assert_requires_property_present new_property_name
    assert_sets_property_present new_property_name
    # plv
    open_project_variable_for_edit(@project, @plv)
    assert_properties_present_for_association_to_project_variable(@project, new_property_name)
    #  card show, card edit
    open_card(@project, @card_1)
    assert_property_present_on_card_show(new_property_name)
    click_edit_link_on_card
    assert_property_is_visible_on_card_edit(new_property_name)
    #  card list, grid, tree view
    open_saved_view ('list view')
    assert_column_present_for new_property_name
    assert_selected_property_for_the_filter(1, new_property_name)
    check_cards_in_list_view(@card_1)
    click_edit_properties_button
    @browser.assert_element_present("bulk_cardrelationshippropertydefinition_#{new_card_property.id}_label")
    switch_to_grid_view
    click_on_card_in_grid_view(@card_1.number)
    assert_property_on_popup("newdependency:#2sampledependency", @card_1.number, 1)
    open_saved_view ('tree view')
    assert_selected_property_for_the_tree_filter(@story_type, 0, new_property_name)
    # history
    @browser.run_once_history_generation
    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(2).shows(:set_properties => {new_property_name => '#2 sample dependency'})
    navigate_to_history_for @project
    assert_properties_in_first_filter_widget({new_property_name => '(any)'})
  end

  def test_change_event_after_deleting_card_property
    dependency_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD, :types => [STORY])
    have_cards_type_default_transitons_prepared_for_test_card_property_changes
    # property management page
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, DEPENDENCY, :stop_at_confirmation => true)
    assert_info_box_light_message("Used by 1 Transition: #{@transition.name}. This will be deleted")
    assert_info_box_light_message("Used by 1 ProjectVariable: #{@plv.name}. This will be disassociated.")
    click_continue_to_delete_link
    assert_notice_message("Property #{DEPENDENCY} has been deleted.")
    assert_property_does_not_exist(dependency_property)
    # card default
    open_edit_defaults_page_for(@project, STORY)
    assert_property_not_present_on_card_defaults(DEPENDENCY)
    # transition
    assert_transition_not_present_on_managment_page_for @project,@transition.name
    # card show, card edit
    open_card(@project, @card_1)
    assert_property_not_present_on_card_show(dependency_property)
    click_edit_link_on_card
    assert_property_not_present_on_card_edit(dependency_property)
    # history
    @browser.run_once_history_generation
    open_card(@project, @card_1)
    assert_history_for(:card, @card_1.number).version(2).does_not_show(:set_properties => {DEPENDENCY => '#2 sample dependency'})
    navigate_to_history_for @project
    assert_property_not_present_in_first_filter_widget(DEPENDENCY)
    # plv
    open_project_variable_for_edit(@project, @plv)
    @browser.assert_text_present('There are no card properties with current data type in this project.')
  end


  private
  def have_cards_type_default_transitons_prepared_for_test_card_property_changes
    @card_as_value = create_card!(:name => 'sample dependency', :card_type => DEFECT)
    @another_card = create_card!(:name => 'sample card_3', :card_type => STORY)
    # card show, card edit, transition
    open_edit_defaults_page_for(@project, STORY)
    set_property_defaults_and_save_default_for(@project, STORY, :properties => {DEPENDENCY => @card_as_value})
    open_card(@project, @card_1)
    set_relationship_properties_on_card_show(DEPENDENCY => @card_as_value)
    @transition = create_transition_for(@project, 'set card property', :type => STORY, :set_properties => {DEPENDENCY => card_number_and_name(@card_as_value)})
    # plv
    @plv = create_project_variable(@project, :name => 'plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :properties => [DEPENDENCY])
  end

  def have_saved_views_prepared_for_test_card_property_changes
    # card list, grid
    navigate_to_view_for(@project, 'list')
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_option(1, DEPENDENCY)
    set_the_filter_value_using_select_lightbox(1, @card_as_value)
    add_column_for(@project, [DEPENDENCY])
    @list_view = create_card_list_view_for(@project, 'list view')
    #card tree
    add_card_to_tree(@tree, @card_1)
    add_card_to_tree(@tree, @another_card)
    add_card_to_tree(@tree, @card_as_value, @card_1)
    navigate_to_tree_view_for(@project, SIMPLE_TREE)
    add_new_tree_filter_for @story_type
    set_the_tree_filter_property_option(@story_type, 0, DEPENDENCY)
    set_the_tree_filter_value_option_to_card_number(@story_type, 0, @card_as_value.number)
    @tree_view = create_card_list_view_for(@project, 'tree view')
  end

  def assert_card_property_not_created(property_name, expected_error_msg = "Name #{property_name} is a reserved property name")
    create_property_definition_for(@project, property_name, :type  => 'Card')
    assert_error_message(expected_error_msg)

    create_property_definition_for(@project, property_name, :type  => 'Card')
    assert_error_message(expected_error_msg)

    navigate_to_property_management_page_for(@project)
    @browser.assert_element_does_not_match('content', /property_name/)
  end

end
