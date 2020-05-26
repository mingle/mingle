# coding: utf-8

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

#Tags: tree-configuration

class Scenario65TreeConfigurationCrudTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'priority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'
  MULTI_BYTE_TYPE = "新闻稿"

  NOTSET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  LOW = 'low'

  PLANNING = 'Planning tree'
  NOTICE_UPDATE_SUCCESS = 'Card tree was successfully updated.'
  NOTICE_CREATE_SUCCESS = 'Card tree was successfully created'
  ERROR_NAME_BLANK = "Name can't be blank"

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_65', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])
    setup_property_definitions(PRIORITY => ['high', LOW], SIZE => [1, 2, 4], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_admin_user
    navigate_to_tree_configuration_management_page_for(@project)
  end

  # bug 4726
  def test_when_reconfigure_tree_give_message_to_delete_fav_filtered_by_relationship_property
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY])
    release_card = create_card!(:name => "release", :card_type => @type_release)
    story_card = create_card!(:name => "story", :card_type => @type_story)
    add_card_to_tree(tree, release_card)
    add_card_to_tree(tree, story_card, release_card)
    navigate_to_card_list_for(@project)
    condition = "Type =#{STORY} AND '#{tree.name} - #{@type_release.name}' = #{release_card.name}"
    set_mql_filter_for(condition)
    mql_view = create_card_list_view_for(@project, 'mql view')
    navigate_to_tree_configuration_for(@project, tree)
    remove_card_type_node_from_tree(0)
    click_save_link
    assert_info_box_light_message("The following 1 team favorite or tab will be deleted: #{mql_view.name}")
  end

  def test_admin_can_create_a_tree_and_hierarchy_is_as_specified_while_creation
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY, TASK])
    assert_notice_message(NOTICE_CREATE_SUCCESS)
    click_configure_current_tree_link
    assert_tree_configuration_nodes_hierarchy(RELEASE, ITERATION_TYPE, STORY, TASK)
  end

  def test_tree_name_should_not_allow_names_with_invalid_characters
    invalid_names = ['test#', '&=#[]', '[abcd]', '123#[]']
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY, TASK])
    navigate_to_tree_configuration_for(@project, tree)
    invalid_names.each {|name| input_tree_name_and_assert_error_message_for(name)}
  end

  def test_only_admin_can_create_or_configure_a_tree
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY])
    assert_notice_message(NOTICE_CREATE_SUCCESS)
    assert_link_configure_tree_on_current_tree_configuration_widget
    navigate_to_tree_configuration_management_page_for(@project)
    assert_can_create_new_card_tree(@project)
    assert_can_edit_a_tree_configuration(@project, tree.name)

    login_as(@non_admin_user.login, 'longtest')
    navigate_to_tree_configuration_management_page_for(@project)
    assert_cannot_create_new_tree(@project)
    assert_cannot_edit_a_tree_configuration(@project, tree.name)
  end

  def test_tree_should_not_allow_blank_tree_name
    click_create_new_card_tree_link
    click_save_link
    assert_error_message('Name can\'t be blank')
  end

  def test_tree_should_have_at_least_two_nodes_and_name_specified_to_create_a_tree
    click_create_new_card_tree_link
    type_tree_name(PLANNING)
    click_save_link
    assert_error_message('You must specify at least 2 valid card types to save this tree.')
    select_type_on_tree_node(0, ITERATION_TYPE)
    click_save_link
    assert_error_message('You must specify at least 2 valid card types to save this tree.')
  end

  def test_delete_links_for_card_type_visible_only_when_more_than_two_card_types_on_cafiguration
    click_create_new_card_tree_link
    type_tree_name(PLANNING)
    assert_remove_tree_node_not_present_for_a_card_type_nodes
    add_new_card_type_node_to(0)
    assert_remove_tree_node_present_for_a_card_type_nodes(2)
    remove_card_type_node_from_tree(0)
    assert_remove_tree_node_not_present_for_a_card_type_nodes
  end

  def test_card_types_displayed_for_a_node_excludes_the_used_once_in_tree_configuration
    click_create_new_card_tree_link
    assert_card_types_in_drop_down_list_on_a_tree_node(0, RELEASE, ITERATION_TYPE, STORY, DEFECT, TASK)
    select_type_on_tree_node(0, RELEASE)
    assert_card_types_not_present_in_drop_down_on_a_tree_node(1, RELEASE)
    select_type_on_tree_node(1, ITERATION_TYPE)
    add_new_card_type_node_to(1)
    assert_card_types_not_present_in_drop_down_on_a_tree_node(2, RELEASE, ITERATION_TYPE)
    select_type_on_tree_node(2, STORY)
    assert_card_types_not_present_in_drop_down_on_a_tree_node(0, RELEASE, ITERATION_TYPE, STORY)
  end

  def test_project_member_should_be_given_proper_error_message_when_tried_to_create_or_edit_tree_through_url
    tree_id =create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE])
    login_as(@non_admin_user.login, 'longtest')
    @browser.open("/projects/#{@project.identifier}/card_trees/new")
    assert_cannot_access_resource_error_message_present
    @browser.open("/projects/#{@project.identifier}/card_trees/edit/#{tree_id}")
    assert_cannot_access_resource_error_message_present
  end

  def test_renaming_a_tree_should_reflect_the_changes
    create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY])
    edit_card_tree_configuration(@project, PLANNING, :new_tree_name => 'story planning')
    assert_notice_message(NOTICE_UPDATE_SUCCESS)
  end

  def test_renaming_a_card_type_should_reflect_changes_on_tree_configuration
    type_iteration_new_name = 'iteration updated'
    @tree = setup_tree(@project, 'Planning2', :types => [@type_release, @type_iteration, @type_story], :relationship_names => ['Planning Tree release', 'Planning Tree iteration'])
    @r1 = create_card!(:name => 'release1', :card_type => @type_release.name)
    add_card_to_tree(@tree, @r1)
    navigate_to_card_type_management_for(@project)
    edit_card_type_for_project(@project, @type_iteration.name, :new_card_type_name => type_iteration_new_name)
    assert_notice_message("Card Type #{type_iteration_new_name} was successfully updated")
    navigate_to_tree_configuration_management_page_for(@project)
    @browser.assert_text_present("#{RELEASE} > #{type_iteration_new_name} > #{STORY}")
    click_on_configure_tree_for(@project, @tree)
    assert_selected_tree_type(1, type_iteration_new_name)
    navigate_to_tree_view_for(@project, @tree.name)
    assert_current_tree_configuration_on_tree_view_page(@type_release.name, type_iteration_new_name, @type_story.name)
  end

  # bug 3234
  def test_leading_and_trailing_whitespace_is_trimmed_on_relationship_property_name_fields
    name_without_leading_and_trailing_whitespace = 'planning tree release'
    name_with_leading_and_trailing_whitespace = "  #{name_without_leading_and_trailing_whitespace}   "
    description_without_leading_and_trailing_whitespace = 'for planning'
    description_with_leading_and_trailing_whitespace = "   #{description_without_leading_and_trailing_whitespace}   "
    tree = create_and_configure_new_card_tree(@project, :name => 'Planning!', :description => description_with_leading_and_trailing_whitespace, :types => [RELEASE, ITERATION_TYPE], :relationship_names => [name_with_leading_and_trailing_whitespace])
    assert_notice_message("Card tree was successfully created")

    property_from_db = TreeRelationshipPropertyDefinition.find(:first, :conditions => ["project_id = ? and name = ?", @project.id, name_without_leading_and_trailing_whitespace])
    assert_equal(name_without_leading_and_trailing_whitespace, property_from_db.name)
    assert_equal(description_without_leading_and_trailing_whitespace, tree.description)
  end

  def test_reconfiguring_tree_in_reverse_order_give_proper_error_messae
    create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY])
    edit_card_tree_configuration(@project, PLANNING, :types => [ITERATION_TYPE, RELEASE])
    assert_error_message('To reorganize the type relationships of an existing tree, you must first delete the card type, save the configuration and then re-add the card type to the new desired position.')
  end

  def test_card_tree_can_be_reconfigured_by_admin
    create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE])
    edit_card_tree_configuration(@project, PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY, TASK])
    assert_notice_message(NOTICE_UPDATE_SUCCESS)
  end

  def test_deleting_a_tree_node_from_configuraiton_warns_about_the_damage_to_tree
    planning_tree = create_and_configure_new_card_tree(@project, :name => PLANNING, :description => "this is a planning tree", :types => [RELEASE, ITERATION_TYPE, STORY, DEFECT])
    assert_notice_message(NOTICE_CREATE_SUCCESS)
    navigate_to_tree_configuration_for(@project, planning_tree)
    remove_card_type_node_from_tree(2)
    click_save_link
    assert_warning_box_present
    assert_warning_messages_on_tree_node_remove(STORY, "#{PLANNING} - #{STORY}")
    click_save_permanently_link
    assert_notice_message('Card tree was successfully updated')
  end

  def test_tree_description_added_should_reflect_on_tree_configuration
    create_and_configure_new_card_tree(@project, :name => PLANNING, :description => "this is a planning tree", :types => [RELEASE, ITERATION_TYPE, STORY])
    assert_notice_message(NOTICE_CREATE_SUCCESS)
    navigate_to_tree_configuration_management_page_for(@project)
    @browser.assert_text_present("this is a planning tree")
    edit_card_tree_configuration(@project, PLANNING, :description => "this is not a planning tree")
    navigate_to_tree_configuration_management_page_for(@project)
    @browser.assert_text_present("this is not a planning tree")
  end

  def test_structure_of_tree_configuraiton_on_tree_management_page
    create_and_configure_new_card_tree(@project, :name => PLANNING, :description => "this is a planning tree", :types => [RELEASE, ITERATION_TYPE, STORY])
    assert_notice_message(NOTICE_CREATE_SUCCESS)
    navigate_to_tree_configuration_management_page_for(@project)
    @browser.assert_text_present("#{RELEASE} > #{ITERATION_TYPE} > #{STORY}")
  end

  def test_trying_to_save_without_name_should_not_wipe_out_configuraiton_with_the_error_message
    create_and_configure_new_card_tree(@project, :name => '', :description => "this is a planning tree", :types => [RELEASE, ITERATION_TYPE, STORY])
    assert_error_message(ERROR_NAME_BLANK)
    assert_tree_configuration_nodes_hierarchy(RELEASE, ITERATION_TYPE, STORY)
  end

  # Admin Navigation related tests
  def test_navigation_from_tree_configuraiton_page_to_tree_management_page
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story])
    navigate_to_tree_configuration_management_page_for(@project)
    assert_current_highlighted_option_on_side_bar_of_management_page('Card trees')
    assert_links_view_hirarchy_and_configure_tree_present_for(@project, planning_tree)

    click_on_configure_tree_for(@project, planning_tree)
    click_cancel_link
    assert_links_view_hirarchy_and_configure_tree_present_for(@project, planning_tree)

    click_on_tree_view_in_card_tree_management_page_for(@project, planning_tree)
    assert_current_tree_on_view(planning_tree.name)

    navigate_to_tree_configuration_management_page_for(@project)
    click_on_hierarchy_view_in_card_tree_management_page_for(@project, planning_tree)
    assert_hierarchy_view_selected
  end

  def test_no_trees_in_project_should_display_proper_info_message
    navigate_to_tree_configuration_management_page_for(@project)
    @browser.assert_text_present("There are currently no trees to list. You can create a new tree from the action bar.")
  end

  def test_admin_user_can_delete_a_tree_configuration_from_project
    r1 = create_card!(:name => 'release1', :card_type => @type_release)
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story],
      :relationship_names => ['PT release', 'PT iteration'])
    add_card_to_tree(planning_tree, r1)
    navigate_to_tree_configuration_management_page_for(@project)
    assert_delete_link_present_on_card_tree_management_admin_page
  end

  def test_non_admin_user_should_not_be_able_to_delete_tree_configuration
    r1 = create_card!(:name => 'release1', :card_type => @type_release)
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story],
      :relationship_names => ['PT release', 'PT iteration'])
    add_card_to_tree(planning_tree, r1)
    login_as(@non_admin_user.login, 'longtest')
    navigate_to_tree_configuration_management_page_for(@project)
    assert_delete_link_not_present_on_card_tree_management_admin_page
  end

  def test_warning_message_for_deleting_a_tree_configuration_from_project
    r1 = create_card!(:name => 'release1', :card_type => @type_release)
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story],
      :relationship_names => ['PT release', 'PT iteration'])
    aggregate_story_count_for_release = setup_aggregate_property_definition('stroy count for release', AggregateType::COUNT, nil, planning_tree.id, @type_release.id, @type_story)
    add_card_to_tree(planning_tree, r1)
    transition_set_release_1 = create_transition(@project, 'move to release 1', :card_type => @type_story, :set_properties => {:'PT release' => r1.id})

    navigate_to_tree_configuration_management_page_for(@project)
    assert_delete_link_present_on_card_tree_management_admin_page
    click_delete_link_for(@project, planning_tree)
    assert_warning_messages_on_tree_delete(:number_of_cards_on_tree => 1, :relationship_properties => ['PT iteration', 'PT release'],
      :aggregate_properties => aggregate_story_count_for_release.name, :transitions => transition_set_release_1.name)
  end

  def test_on_delete_the_tree_configuration_gets_removed_from_admin_page
    r1 = create_card!(:name => 'release1', :card_type => @type_release)
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story],
      :relationship_names => ['PT release', 'PT iteration'])
    add_card_to_tree(planning_tree, r1)
    navigate_to_tree_configuration_management_page_for(@project)
    assert_delete_link_present_on_card_tree_management_admin_page
    delete_tree_configuration_for(@project, planning_tree)
    assert_notice_message("Card tree #{planning_tree.name} has been deleted.")
    @browser.assert_text_present('There are currently no trees to list. You can create a new tree from the action bar.')
  end

  #bug 2944
  def test_project_name_card_trees_will_not_break_app_on_moving_to_tree_configuraiton_page
    click_all_projects_link
    card_trees_project = create_new_project('card trees')
    navigate_to_tree_configuration_management_page_for(card_trees_project)
    @browser.assert_text_present("There are currently no trees to list. You can create a new tree from the action bar.")
    click_all_tab
    assert_info_message("There are no cards for #{card_trees_project.name}")
  end

  # bug 2952
  def test_navigation_from_tree_configuraiton_page_to_tree_management_page
    planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story],
      :relationship_names => ['Planning Tree release', 'Planning Tree iteration'])
    navigate_to_tree_configuration_management_page_for(@project)
    assert_current_highlighted_option_on_side_bar_of_management_page('Card trees')
    navigate_to_tree_configuration_for(@project, planning_tree)
    click_cancel_link
    assert_project_admin_menu_item_is_highlighted('Card trees')
  end

  # bug 3103, # 2970
   def test_type_defaults_for_relationship_properties_gets_updated_on_re_configuring_tree
     @r1 = create_card!(:name => 'release1', :card_type => @type_release.name)
     create_and_configure_new_card_tree(@project, :name => PLANNING, :description => "this is a planning tree", :types => [RELEASE, ITERATION_TYPE, STORY])
     navigate_to_card_type_management_for(@project)
     set_property_defaults_and_save_default_for(@project, ITERATION_TYPE, :properties => {"#{PLANNING} - #{RELEASE}" => @r1}, :description => "h3. Iteration details")
     assert_notice_message("Defaults for card type #{ITERATION_TYPE} were successfully updated")
     edit_card_tree_configuration(@project, PLANNING, :types => [RELEASE, STORY])
     open_edit_defaults_page_for(@project, ITERATION_TYPE)
     assert_property_not_present_on_card_defaults("#{PLANNING} - #{RELEASE}")
   end

  #bug 7594, 3145
  def test_links_on_the_warning_message_of_not_enough_card_types_for_tree_creation_should_work
    empty_project = create_project(:prefix => 'empty_project')
    navigate_to_tree_configuration_management_page_for(empty_project)

    click_create_new_card_tree_link
    assert_tree_configuration_form_not_present
    assert_info_message("Trees require at least two card types in a project")
    click_link("Return to the card type list")
    @browser.assert_location("/projects/#{empty_project.identifier}/card_types/list")
    assert_link_present("/projects/#{empty_project.identifier}/card_types/new")
  end

  # bug 3370
  def test_cannot_create_with_tree_the_name_of_none
    nones = ['none', 'NONE', 'None']
    nones.each do |none|
      open_create_new_tree_page_for(@project)
      assert_cannot_create_tree_with_name(none)
    end
  end

  # bug 3370
  def test_cannot_update_tree_with_the_name_of_none
    tree = setup_tree(@project, 'foo', :types => [@type_iteration, @type_story], :relationship_names => ['foo property'])
    nones = ['none', 'NONE', 'None']
    nones.each do |none|
      open_configure_a_tree_through_url(@project, tree)
      assert_cannot_create_tree_with_name(none)
    end
  end

  # bug 3654
   def test_can_cancel_during_tree_configuration_update
     planning_tree = setup_tree(@project, 'Planning Tree', :types => [@type_release, @type_iteration, @type_story],
       :relationship_names => ['Planning Tree release', 'Planning Tree iteration'])
     navigate_to_tree_configuration_management_page_for(@project)
     click_on_configure_tree_for(@project, planning_tree)
     click_save_link
     remove_card_type_tree(@project, planning_tree, ITERATION_TYPE)
     click_save_link
     @browser.assert_text_present("We recommend that you review the following changes that will result from this reconfiguration of #{planning_tree.name}:")
     click_cancel_link
     @browser.assert_text_not_present("We're sorry")
     navigate_to_tree_configuration_for(@project, planning_tree)
     assert_tree_configuration_nodes_hierarchy(RELEASE, ITERATION_TYPE, STORY)
   end

  # bug 3681
  def test_clicking_up_after_renaming_tree_does_not_cause_were_sorry
    tree = setup_tree(@project, 'foo', :types => [@type_iteration, @type_story], :relationship_names => ['foo property'])
    navigate_to_tree_configuration_management_page_for(@project)
    click_on_tree_view_in_card_tree_management_page_for(@project, tree)
    click_on_configure_tree_for(@project, tree)
    type_tree_name('new tree name')
    click_save_link
    assert_notice_message("Card tree was successfully updated.")
    click_up
    @browser.assert_text_not_present("We're sorry")
    @browser.assert_location("/projects/#{@project.identifier}/cards/tree?tab=All&tree_id=#{tree.id}")
  end

  # bug 3710 --- this test will not fail individually; you have to run the whole file
  def test_clicking_up_after_renaming_tree_does_not_cause_were_sorry
    tree = setup_tree(@project, 'foo', :types => [@type_iteration, @type_story], :relationship_names => ['foo property'])
    navigate_to_tree_configuration_management_page_for(@project)
    click_on_configure_tree_for(@project, tree)
    type_tree_name('new tree name')
    click_save_link
    assert_notice_message("Card tree was successfully updated.")
    click_up
    @browser.assert_text_not_present("We're sorry")
    @browser.assert_location("/projects/#{@project.identifier}/card_trees/list")
  end

  # bug 3732
  def test_deleting_tree_after_viewing_it_does_not_cause_were_sorry_page
    tree_one = setup_tree(@project, 'tree one', :types => [@type_iteration, @type_story], :relationship_names => ['one property'])
    tree_two = setup_tree(@project, 'tree two', :types => [@type_iteration, @type_story], :relationship_names => ['two property'])
    click_all_tab
    select_tree(tree_one)
    switch_to_tree_view
    @browser.click_and_wait "link=Project admin"
    click_project_admin_menu_link_for('Card trees')
    delete_tree_configuration_for(@project, tree_one)
    assert_notice_message("Card tree #{tree_one.name} has been deleted.")
  end

  # bugs 3929, 3107
  def test_should_be_able_to_create_and_use_tree_when_type_has_multi_byte_characters
    multi_byte_type = setup_card_type(@project, MULTI_BYTE_TYPE, :properties => [])
    tree = create_and_configure_new_card_tree(@project, :name => 'multi-byte tree', :types => [MULTI_BYTE_TYPE, STORY])
    assert_notice_message(NOTICE_CREATE_SUCCESS)
    click_configure_current_tree_link
    assert_tree_configuration_nodes_hierarchy(MULTI_BYTE_TYPE, STORY)
  end

  # bug 3218
  def test_that_tree_names_are_smart_sorted_on_configuration_page
    tree_two = setup_tree(@project, 'Release Planning', :types => [@type_iteration, @type_story], :relationship_names => ['two property'])
    tree_one = setup_tree(@project, 'a release plan', :types => [@type_iteration, @type_story], :relationship_names => ['one property'])
    tree_three = setup_tree(@project, 'story breakdown', :types => [@type_iteration, @type_story], :relationship_names => ['two property'])
    navigate_to_tree_configuration_management_page_for(@project)

    assert_tree_position_in_list('a release plan', 0)
    assert_tree_position_in_list('Release Planning', 1)
    assert_tree_position_in_list('story breakdown', 2)
  end

  # bug 4907
  def test_tree_selection_drop_down_is_updated_after_adding_new_tree
    navigate_to_card_list_for @project
    assert_tree_selection_droplist_not_present
    tree_one = setup_tree(@project, 'a release plan', :types => [@type_iteration, @type_story], :relationship_names => ['one property'])
    navigate_to_card_list_for @project
    assert_tree_selection_droplist_present
    @browser.click('workspace_selector_panel')
    assert_tree_present_in_tree_selection_drop_down(tree_one)
  end

  # bug 4079
  def test_editing_relationship_name_does_not_lose_link_look_when_clicking_elsewhere_on_page_while_in_the_middle_of_an_edit
    tree = create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE])
    click_configure_current_tree_link
    assert_edit_relationship_link_visible(:type_node_number => 0)
    click_edit_relationship_link(:type_node_number => 0)
    @browser.blur('relationship_0_name_field')
    assert_edit_relationship_link_visible(:type_node_number => 0)
  end

  def assert_cannot_create_tree_with_name(name)
    type_tree_name(name)
    click_save_link
    assert_error_message_without_html_content("Name cannot be #{name}")
    navigate_to_tree_configuration_management_page_for(@project)
    assert_tree_not_present_on_management_page(name)
  end

  private
  def input_tree_name_and_assert_error_message_for(name)
    type_tree_name(name)
    click_save_link
    assert_error_message_without_html_content("Name should not contain '&', '=', '#', '[' and ']' characters")
  end
end
