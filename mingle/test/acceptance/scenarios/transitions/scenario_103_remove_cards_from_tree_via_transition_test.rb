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

# Tags: tree-usage, transitions
class Scenario103RemoveCardsFromTreeViaTransitionTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  STATUS = 'Status'
  SIZE = 'Size'

  TYPE_RELEASE = 'release'
  TYPE_ITERATION = 'iteration'
  TYPE_STORY = 'story'

  RELATION_PROPERTY_RELEASE = 'planning - release'
  RELATION_PROPERTY_ITERATION = 'planning - iteration'
  PLANNING_TREE = 'planning tree'

  OPEN = 'open'
  CLOSED = 'closed'

  REMOVE_CARD = '(remove card from this tree)'
  REMOVE_CARD_AND_ITS_CHILDREN = "(remove card and its children from this tree)"
  NOCHANGE = '(no change)'
  NOTSET = '(not set)'
  USER_INPUT_REQUIRED = '(user input - required)'
  DETERMINED_BY_TREE_MEMBERSHIP = '(determined by relationships)'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @mingle_admin = users(:admin)
    @project = create_project(:prefix => 'scenario_103_project', :users => [@team_member], :admins => [@mingle_admin, @project_admin])
    @status = setup_property_definitions(STATUS => [OPEN, CLOSED])
    @size = setup_numeric_property_definition(SIZE, ['1', '3', '5'])
    @type_release = setup_card_type(@project, TYPE_RELEASE)
    @type_iteration = setup_card_type(@project, TYPE_ITERATION)
    @type_story = setup_card_type(@project, TYPE_STORY, :properties => [STATUS, SIZE])
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story],
      :relationship_names => [RELATION_PROPERTY_RELEASE, RELATION_PROPERTY_ITERATION])
    login_as_admin_user
  end

  # admin related tests
  def test_tree_options_to_remove_cards_from_tree_on_transition_create_page
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(TYPE_RELEASE)
    assert_tree_options_present_on_events_for(@planning_tree, [REMOVE_CARD, REMOVE_CARD_AND_ITS_CHILDREN])
    set_card_type_on_transitions_page(TYPE_ITERATION)
    assert_tree_options_present_on_events_for(@planning_tree, [REMOVE_CARD, REMOVE_CARD_AND_ITS_CHILDREN])
    set_card_type_on_transitions_page(TYPE_STORY)
    assert_tree_options_present_on_events_for(@planning_tree, [REMOVE_CARD])
    assert_tree_options_not_present_on_events_for(@planning_tree, REMOVE_CARD_AND_ITS_CHILDREN)
  end

  def test_setting_relationship_property_to_notset_disable_tree_options_dropdown
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(TYPE_STORY)
    set_sets_properties(@project, RELATION_PROPERTY_RELEASE => NOTSET)
    assert_tree_option_widget_is_disabled_for(@planning_tree)
    assert_select_option_label_for_transition(@planning_tree, NOCHANGE)


    set_sets_properties(@project, RELATION_PROPERTY_RELEASE => USER_INPUT_REQUIRED)
    assert_tree_option_widget_is_disabled_for(@planning_tree)
    assert_select_option_label_for_transition(@planning_tree, DETERMINED_BY_TREE_MEMBERSHIP)


    set_sets_properties(@project, RELATION_PROPERTY_RELEASE => NOCHANGE)
    assert_tree_option_widget_is_enabled_for(@planning_tree)
    assert_select_option_label_for_transition(@planning_tree, NOCHANGE)
  end

  def test_setting_tree_option_event_will_set_relationship_property_to_notset_and_disable_them
    open_transition_create_page(@project)
    set_card_type_on_transitions_page(TYPE_STORY)
    set_tree_option_event_for(@planning_tree => REMOVE_CARD)
    assert_sets_property_and_value_read_only(@project, RELATION_PROPERTY_RELEASE, NOTSET)
    assert_sets_property_and_value_read_only(@project, RELATION_PROPERTY_ITERATION, NOTSET)

    set_card_type_on_transitions_page(TYPE_ITERATION)
    set_tree_option_event_for(@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN)
    assert_sets_property_and_value_read_only(@project, RELATION_PROPERTY_RELEASE, NOTSET)

    set_tree_option_event_for(@planning_tree => NOCHANGE)
    assert_sets_property(RELATION_PROPERTY_ITERATION => NOCHANGE)
  end

  def test_transition_list_view_page_shows_select_options_set_by_transition
    transition1 = create_transition_for(@project, 'remove this card', :type => TYPE_STORY, :tree_option => {@planning_tree => REMOVE_CARD})
    assert_property_set_on_transition_list_for_transtion(transition1, {RELATION_PROPERTY_RELEASE => NOTSET, RELATION_PROPERTY_ITERATION => NOTSET})
    assert_tree_property_set_on_transition_list_for_transtion(transition1, PLANNING_TREE => REMOVE_CARD)

    transition_updated = edit_transition_for(@project, transition1, :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    assert_property_set_on_transition_list_for_transtion(transition_updated, {RELATION_PROPERTY_RELEASE => NOTSET})
    assert_tree_property_set_on_transition_list_for_transtion(transition_updated, PLANNING_TREE => REMOVE_CARD_AND_ITS_CHILDREN)

    edit_transition_for(@project, transition_updated, :tree_option => {@planning_tree => NOCHANGE})
    assert_error_message('Transition must set at least one property.')
  end

  def test_removing_child_from_configuration_updates_the_transition_which_say_remove_card_and_its_children_from_this_tree
    transition1 = create_transition_for(@project, 'remove this card', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    assert_property_set_on_transition_list_for_transtion(transition1, {RELATION_PROPERTY_RELEASE => NOTSET})
    assert_tree_property_set_on_transition_list_for_transtion(transition1, PLANNING_TREE => REMOVE_CARD_AND_ITS_CHILDREN)
    remove_a_card_type_and_save_tree_configuraiton(@project, @planning_tree, TYPE_STORY)
    navigate_to_transition_management_for(@project)
    assert_property_set_on_transition_list_for_transtion(transition1, {RELATION_PROPERTY_RELEASE => NOTSET})
    assert_tree_property_set_on_transition_list_for_transtion(transition1, PLANNING_TREE => REMOVE_CARD)
  end

  def test_renaming_tree_name_updates_the_transition
    new_name = 'planning tree2'
    transition1 = create_transition_for(@project, 'remove this card', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    assert_property_set_on_transition_list_for_transtion(transition1, {RELATION_PROPERTY_RELEASE => NOTSET})
    assert_tree_property_set_on_transition_list_for_transtion(transition1, PLANNING_TREE => REMOVE_CARD_AND_ITS_CHILDREN)

    edit_card_tree_configuration(@project, PLANNING_TREE, :new_tree_name => new_name)
    navigate_to_transition_management_for(@project)
    assert_property_set_on_transition_list_for_transtion(transition1,{RELATION_PROPERTY_RELEASE => NOTSET})
    assert_tree_property_set_on_transition_list_for_transtion(transition1, new_name => REMOVE_CARD_AND_ITS_CHILDREN)
  end

  def test_deleting_tree_deletes_transition_which_is_set_to_remove_cards
    transition1 = create_transition_for(@project, 'remove this card', :type => TYPE_STORY, :tree_option => {@planning_tree => REMOVE_CARD})
    transition2 = create_transition_for(@project, 'remove this card and its children', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    navigate_to_tree_configuration_management_page_for(@project)
    delete_tree_configuration_for(@project, @planning_tree)
    assert_transition_not_present_for(@project, transition1)
    assert_transition_not_present_for(@project, transition2)
  end

  def test_deleting_node_from_one_tree_should_not_delete_transition_which_user_same_node_type_by_other_tree
    tree2 = setup_tree(@project, 'tree2', :types => [@type_iteration, @type_story], :relationship_names => ['relation - tree2'])
    transition1 = create_transition_for(@project, 'remove this card', :type => TYPE_STORY, :tree_option => {tree2 => REMOVE_CARD})
    transition2 = create_transition_for(@project, 'remove story', :type => TYPE_STORY, :tree_option => {@planning_tree => REMOVE_CARD})
    remove_a_card_type_and_wait_on_confirmation_page(@project, @planning_tree, @type_story)
    assert_info_box_light_message("The following 1 transition will be deleted: #{transition2.name}.")
    click_save_permanently_link
    assert_transition_present_for(@project, transition1)
    assert_transition_not_present_for(@project, transition2)
  end

  # card show page related test
  def test_on_executing_a_transition_to_remove_this_card_set_all_relationship_properties_to_notset_on_card_show
    add_cards_on_planning_tree
    transition1 = create_transition_for(@project, 'remove this card', :type => TYPE_STORY, :tree_option => {@planning_tree => REMOVE_CARD})
    open_card(@project, @story_card.number)
    assert_properties_set_on_card_show({RELATION_PROPERTY_RELEASE => card_number_and_name(@release_card), RELATION_PROPERTY_ITERATION => card_number_and_name(@iteration_card)})
    assert_card_belongs_to_tree_on_card_show_for(@planning_tree)
    click_transition_link_on_card(transition1)
    assert_properties_set_on_card_show({RELATION_PROPERTY_RELEASE => NOTSET, RELATION_PROPERTY_ITERATION => NOTSET})
    assert_card_is_available_to_tree_on_card_show_for(@planning_tree)
  end

  def test_on_executing_a_transition_to_remove_this_card_and_its_children_set_all_relationship_properties_to_notset_on_card_show
    add_cards_on_planning_tree
    transition2 = create_transition_for(@project, 'remove this card and its children', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    open_card(@project, @iteration_card.number)
    assert_properties_set_on_card_show({RELATION_PROPERTY_RELEASE => card_number_and_name(@release_card)})
    assert_card_belongs_to_tree_on_card_show_for(@planning_tree)
    click_transition_link_on_card(transition2)
    assert_properties_set_on_card_show({RELATION_PROPERTY_RELEASE => NOTSET})
    assert_card_is_available_to_tree_on_card_show_for(@planning_tree)

    open_card(@project, @story_card.number)
    assert_properties_set_on_card_show({RELATION_PROPERTY_RELEASE => NOTSET, RELATION_PROPERTY_ITERATION => NOTSET})
    assert_card_is_available_to_tree_on_card_show_for(@planning_tree)
  end

  # card list related test
  def test_on_executing_a_transition_to_remove_this_card_on_list_view
    add_cards_on_planning_tree
    add_card_to_tree(@planning_tree, @iteration_card, @release_card)

    transition = create_transition_for(@project, 'remove this card and its children', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    navigate_to_view_for(@project, 'list', {:tree_name  => PLANNING_TREE})
    assert_card_present_in_list(@iteration_card)
    assert_card_present_in_list(@story_card)
    check_cards_in_list_view(@iteration_card)
    execute_bulk_transition_action(transition)
    assert_card_not_present_in_list(@iteration_card)
    assert_card_not_present_in_list(@story_card)
    # assert_notice_message("#{transition.name} successfully applied to card ##{@iteration_card.number}") -see bug #3263
  end

  def test_bulk_execution_of_remove_cards_from_tree_on_list_view
    add_cards_on_planning_tree
    iteration_card2 = create_card!(:name => 'iteration 2', :type => TYPE_ITERATION)
    add_card_to_tree(@planning_tree, iteration_card2, @release_card)

    transition = create_transition_for(@project, 'remove this card and its children', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    navigate_to_view_for(@project, 'list', {:tree_name  => PLANNING_TREE})
    assert_card_present_in_list(@iteration_card)
    assert_card_present_in_list(@story_card)
    check_cards_in_list_view(@iteration_card, iteration_card2)
    execute_bulk_transition_action(transition)
    assert_cards_not_present_in_list(@iteration_card, iteration_card2, @story_card)
    # assert_notice_message("#{transition.name} successfully applied to card ##{@iteration_card.number}") -see bug #3263
  end

   # grid view related test
  def test_on_executing_a_transition_to_remove_this_card_on_grid_view
    add_cards_on_planning_tree
    transition = create_transition_for(@project, 'remove this card and its children', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    navigate_to_view_for(@project, 'grid', {:tree_name  => PLANNING_TREE})
    assert_cards_present_in_grid_view(@iteration_card, @story_card)
    click_on_transition_for_card_in_grid_view(@iteration_card, transition)
    assert_cards_not_present_in_grid_view(@iteration_card, @story_card)
    # assert_notice_message("#{transition.name} successfully applied to card ##{@iteration_card.number}") #-no notice message for transition execution on grid
  end

  # tree view related test
  def test_on_executing_a_transition_to_remove_this_card_on_tree_view
    add_cards_on_planning_tree
    transition = create_transition_for(@project, 'Removeall', :type => TYPE_ITERATION, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    navigate_to_tree_view_for(@project, @planning_tree.name)
    assert_cards_showing_on_tree(@iteration_card, @story_card)

    click_on_transition_for_card_in_tree_view(@iteration_card, transition)
    assert_cards_not_showing_on_tree(@iteration_card, @story_card)
    assert_notice_message("#{transition.name} successfully applied to card ##{@iteration_card.number}")
  end

  def test_on_executing_a_transition_to_remove_this_card_and_its_children_for_root_element_card_on_tree_view
    add_cards_on_planning_tree
    transition = create_transition_for(@project, 'Removeall', :type => TYPE_RELEASE, :tree_option => {@planning_tree => REMOVE_CARD_AND_ITS_CHILDREN})
    navigate_to_tree_view_for(@project, @planning_tree.name)
    assert_cards_showing_on_tree(@release_card, @iteration_card, @story_card)

    click_on_transition_for_card_in_tree_view(@release_card, transition)
    assert_cards_not_showing_on_tree(@release_card, @iteration_card, @story_card)
    assert_notice_message("#{transition.name} successfully applied to card ##{@release_card.number}")
  end

  def add_cards_on_planning_tree
    @release_card = create_card!(:name => 'release 1', :type => TYPE_RELEASE)
    @iteration_card = create_card!(:name => 'iteration 1', :type => TYPE_ITERATION)
    @story_card = create_card!(:name => 'story 1', :type => TYPE_STORY)
    add_card_to_tree(@planning_tree, @release_card)
    add_card_to_tree(@planning_tree, @iteration_card, @release_card)
    add_card_to_tree(@planning_tree, @story_card, @iteration_card)
  end

  # bug 4586
  def test_tree_options_and_relationship_remain_disabled_on_transition_edit_page
    transition1 = create_transition_for(@project, 'remove this card', :type => TYPE_STORY, :tree_option => {@planning_tree => REMOVE_CARD})
    open_transition_for_edit(@project, transition1)
    assert_sets_property_and_value_read_only(@project, RELATION_PROPERTY_RELEASE, NOTSET)
    assert_sets_property_and_value_read_only(@project, RELATION_PROPERTY_ITERATION, NOTSET)
  end


end
