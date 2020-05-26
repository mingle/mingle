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

# Tags: scenario, tree-view, card-types, properties
class Scenario88CardsInTreesTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PLANNING_TREE = 'Planning Tree'
  RELEASE_PROPERTY = 'Planning Tree release'
  ITERATION_PROPERTY = 'Planning Tree iteration'

  TYPE = 'Type'
  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'
  CARD = 'Card'
  LITTLE_CARD = 'little card'
  NOT_SET = '(not set)'

  DEPENDENCY = 'Dependency'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @project_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_88', :admins => [@project_admin], :users => [@project_member])
    @type_story = setup_card_type(@project, STORY)
    @type_iteration = setup_card_type(@project, ITERATION)
    @type_release = setup_card_type(@project, RELEASE)
    # @card_property = create_property_definition_for(@project, DEPENDENCY, :type => CARD, :types => STORY)
    login_as_admin_user
    @release1 = create_card!(:name => 'release 1', :description => "super plan", :card_type => RELEASE)
    @release2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @iteration2 = create_card!(:name => 'iteration 2', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [RELEASE_PROPERTY, ITERATION_PROPERTY])
  end

  def test_quick_add_cards_for_tree_in_grid_view
    add_cards_to_get_a_basic_RIS_tree
    navigate_to_grid_view_for(@project)
    select_tree(@planning_tree.name)
    add_card_via_quick_add('new story', :type => STORY)
    assert_notice_message("Card #6 was successfully created.")
    @browser.assert_text_present("Card #6 was successfully created, but is not shown because it does not match the current filter.")
    number = add_card_via_quick_add('another new story', :type => STORY)
    open_card_for_edit(@project, number)
    set_relationship_properties_on_card_edit(RELEASE_PROPERTY => @release1)
    save_card

    new_card = find_card_by_name("another new story")
    navigate_to_grid_view_for(@project)
    select_tree(@planning_tree.name)

    assert_cards_present_in_grid_view(new_card)
  end

  def test_quick_add_with_tree_selected_should_not_add_cards_to_root_if_relationship_properties_are_not_set_in_card_defaults
    add_cards_to_get_a_basic_RIS_tree
    navigate_to_hierarchy_view_for(@project, @planning_tree)
    add_card_via_quick_add("new story card", :type => STORY)
    new_story_card = find_card_by_name("new story card")
    navigate_to_tree_view_for(@project, @planning_tree.name)
    assert_cards_not_showing_on_tree(new_story_card)
  end

  def test_can_delete_one_card_that_belonging_to_a_tree
    reverted_tree = setup_tree(@project, 'reverted tree', :types => [@type_story, @type_iteration, @type_release], :relationship_names => ['Reverted tree story', 'Reverted tree iteration'])
    add_cards_to_get_a_basic_RIS_tree

    add_card_to_tree(reverted_tree, @story1)
    add_card_to_tree(reverted_tree, @iteration1, @story1)
    add_card_to_tree(reverted_tree, @release1, @iteration1)

    open_card(@project, @story1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, @release1)
    assert_property_set_on_card_show(ITERATION_PROPERTY, @iteration1)

    open_card(@project, @release1)
    assert_property_set_on_card_show('Reverted tree story', @story1)
    assert_property_set_on_card_show('Reverted tree iteration', @iteration1)

    open_card(@project, @iteration1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, @release1)
    assert_property_set_on_card_show('Reverted tree story', @story1)

    assert_delete_link_present
    click_card_delete_link

    click_continue_to_delete_on_confirmation_popup
    assert_notice_message("Card ##{@iteration1.number} deleted successfully.")

    open_card(@project, @story1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, @release1)
    assert_property_set_on_card_show(ITERATION_PROPERTY, NOT_SET)

    open_card(@project, @release1)
    assert_property_set_on_card_show('Reverted tree story', @story1)
    assert_property_set_on_card_show('Reverted tree iteration', NOT_SET)
  end

  def test_can_bulk_delete_cards_in_a_tree
    card_1 = create_card!(:name => 'card_1', :card_type => CARD)
    default_type = card_1.card_type
    four_levels_tree = setup_tree(@project, 'four levels tree', :types => [@type_release, @type_iteration, @type_story, default_type], :relationship_names => ['four-release', 'four-iteration', 'four-story'])
    add_card_to_tree(four_levels_tree, @release1)
    add_card_to_tree(four_levels_tree, @iteration1, @release1)
    add_card_to_tree(four_levels_tree, @story1, @iteration1)
    add_card_to_tree(four_levels_tree, card_1, @story1)
    open_card(@project, card_1)
    assert_property_set_on_card_show('four-release', @release1)
    assert_property_set_on_card_show('four-iteration', @iteration1)
    assert_property_set_on_card_show('four-story', @story1)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@iteration1, @story1)
    click_bulk_delete_button
    expected_message =  "Belongs to 1 tree: #{four_levels_tree.name}. Any child cards will remain in the tree.
                        Used as a tree relationship property value on 2 cards. Tree relationship properties,four-iteration and four-story,will be (notset) for all affected cards.
                        Any MQL (Advanced filters, some Macros or aggregates using MQL conditions) that uses these cards will no longer return any results.
                        Pages and tables/charts that reference these cards will no longer work.
                        Any dependencies raised or resolved by this card will be deleted or unlinked.
                        Any personal favorites that use these cards may not work as expected.
                        Previously subscribed atom feeds that use these cards will no longer provide new data."
    assert_info_box_light_message(expected_message, :id => "confirm-delete-div", :include => true)
    click_confirm_bulk_delete
    assert_notice_message("Cards deleted successfully.")
    open_card(@project, card_1)
    assert_property_set_on_card_show('four-release', @release1)
    assert_property_set_on_card_show('four-iteration', NOT_SET)
    assert_property_set_on_card_show('four-story', NOT_SET)
  end

  def test_bulk_delete_when_some_cards_in_a_tree_and_some_cards_are_not_should_work
    new_story_1 = create_card!(:name => 'new story 1', :card_type => STORY)
    new_story_2 = create_card!(:name => 'new_story_2', :card_type => STORY)
    new_iteration_1 = create_card!(:name => 'new iteration 1',:card_type => ITERATION)
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, [@story1, new_story_1], @iteration1)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(new_story_1, @iteration1, new_story_2, new_iteration_1)
    click_bulk_delete_button
    click_confirm_bulk_delete
    assert_notice_message("Cards deleted successfully.")
    open_card(@project, @story1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, @release1)
    assert_property_set_on_card_show(ITERATION_PROPERTY, NOT_SET)
  end

  def test_deletion_of_cards_in_tree_and_cards_as_values_of_card_relationship_properties_should_work_consistently
    other_card = create_property_definition_for(@project, DEPENDENCY, :type => 'card', :types => [STORY])
    new_iteration_1 = create_card!(:name => 'new iteration 1',:card_type => ITERATION)
    new_iteration_2 = create_card!(:name => 'new iteration 2',:card_type => ITERATION)
    new_story_1 = create_card!(:name => 'new story 1', :card_type => STORY)
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree,[@iteration1, new_iteration_1, new_iteration_2], @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    add_card_to_tree(@planning_tree, new_story_1, new_iteration_1)
    open_card(@project, @story1)
    set_relationship_properties_on_card_show(DEPENDENCY => new_iteration_1)
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@iteration1, new_iteration_1, new_iteration_2, new_story_1)
    click_bulk_delete_button
    click_confirm_bulk_delete
    assert_notice_message("Cards deleted successfully.")
    open_card(@project, @story1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, @release1)
    assert_property_set_on_card_show(ITERATION_PROPERTY, NOT_SET)
    assert_property_set_on_card_show(DEPENDENCY, NOT_SET)
  end


  # bug 5198
  def test_setting_a_card_relationship_property_on_card_view_should_not_set_another_card_relationship_as_NOT_SET_when_it_is_should_not
    add_card_to_tree(@planning_tree, @release1)
    add_card_to_tree(@planning_tree, @iteration1, @release1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    open_card(@project, @story1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, @release1)
    assert_property_set_on_card_show(ITERATION_PROPERTY, @iteration1)
    set_relationship_properties_on_card_show(RELEASE_PROPERTY => @release1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, @release1)
    assert_property_set_on_card_show(ITERATION_PROPERTY, @iteration1)
  end

  # bug 4701
  def test_changing_card_type_will_not_disassociate_children_of_cards_whose_type_does_not_actually_change
    add_cards_to_get_a_basic_RIS_tree
    navigate_to_card_list_for(@project)
    check_cards_in_list_view(@release1,@iteration1)
    click_edit_properties_button
    set_card_type_on_bulk_edit(ITERATION)
    navigate_to_tree_view_for(@project, @planning_tree.name)
    assert_card_directly_under_root(@planning_tree, @release1.reload)
    assert_card_directly_under_root(@planning_tree, @iteration1.reload)
    assert_card_showing_on_tree(@story1)
    open_card(@project, @story1)
    assert_property_set_on_card_show(RELEASE_PROPERTY, NOT_SET)
    assert_property_set_on_card_show(ITERATION_PROPERTY, @iteration1)
  end

  # bug 7452
  def test_can_change_card_type_in_card_edit_mode_from_a_type_in_tree_to_a_type_not_valid_for_tree
    add_cards_to_get_a_basic_RIS_tree
    open_card_for_edit(@project, @story1.number)
    set_properties_in_card_edit(TYPE => CARD)
    click_save_for_card_type_change
    assert_card_type_set_on_card_show(CARD)
  end

  def test_create_new_children_link_appears_on_card_that_belongs_to_tree_and_card_is_not_bottom_most_level
    add_card_to_tree(@planning_tree, @release1)
    open_card(@project, @release1)
    assert_card_in_tree(@project, @planning_tree, @release1)
    assert_create_new_children_link_present_for(@planning_tree)
    assert_create_children_link_hover_text_for_tree(@planning_tree, 'Create children for the tree')
  end

  # bug 3748
  def test_create_new_children_link_should_not_appear_on_card_that_does_not_belong_to_tree
    open_card(@project, @release2)
    assert_card_not_in_tree(@project, @planning_tree, @release2)
    assert_create_new_children_link_not_present_for(@planning_tree)
  end

  # bug 3748
  def test_create_new_children_link_should_not_appear_on_card_that_is_bottom_most_level_of_tree
    add_card_to_tree(@planning_tree, @iteration1)
    add_card_to_tree(@planning_tree, @story1, @iteration1)
    open_card(@project, @release1)
    assert_card_in_tree(@project, @planning_tree, @story1)
    assert_create_new_children_link_not_present_for(@planning_tree)
  end

  # bug 3222
  def test_messages_on_card_show_correctly_say_whether_card_is_in_tree_or_not
    open_card(@project, @release1)
    assert_card_available_to_tree_message_present_for(@planning_tree)
    click_edit_link_on_card
    assert_card_available_to_tree_message_present_for(@planning_tree, 'edit')

    add_card_to_tree(@planning_tree, @release1)
    open_card(@project, @release1)
    assert_card_belongs_to_tree_message_present_for(@planning_tree)

    add_card_to_tree(@planning_tree, @iteration1)
    open_card(@project, @iteration1)
    assert_card_belongs_to_tree_message_present_for(@planning_tree)
    click_edit_link_on_card
    assert_card_belongs_to_tree_message_present_for(@planning_tree, 'edit')

    add_card_to_tree(@planning_tree, @iteration1, @release1)
    open_card(@project, @iteration1)
    assert_card_belongs_to_tree_message_present_for(@planning_tree)

    set_card_type_on_card_show(CARD)
    assert_no_tree_availability_message_present_for(@planning_tree)

    open_card(@project, @iteration1)
    set_card_type_on_card_show(ITERATION)
    assert_card_available_to_tree_message_present_for(@planning_tree)
    open_card(@project, @iteration1)
    set_relationship_properties_on_card_show(RELEASE_PROPERTY => @release1)
    assert_card_belongs_to_tree_message_present_for(@planning_tree)

    click_edit_link_on_card
    assert_card_belongs_to_tree_message_present_for(@planning_tree, 'edit')
  end

  # bug 4649
 def test_dragging_card_to_its_grand_parent_it_should_remain_in_its_grand_prarent
   add_cards_to_get_a_basic_RIS_tree
   navigate_to_tree_view_for(@project,@planning_tree.name)
   assert_parent_node(@iteration1, @story1)

   drag_and_drop_card_in_tree(@release1, @story1)
   assert_parent_node(@release1, @story1)

   root = @planning_tree.create_tree.root
   drag_and_drop_card_in_tree(root, @story1)
   assert_first_level_node(@story1)
 end

  # bug 4713
   def test_change_card_type_should_not_disassociate_parents_and_children
     add_card_to_tree(@planning_tree, @release1)
     add_card_to_tree(@planning_tree, @release2)
     add_card_to_tree(@planning_tree, @iteration1, @release1)
     add_card_to_tree(@planning_tree, @iteration2, @release2)
     add_card_to_tree(@planning_tree, @story1, @iteration1)
     story2 = create_card!(:name => 'story 2', :card_type => STORY)
     add_card_to_tree(@planning_tree, story2, @iteration2)

     navigate_to_card_list_by_clicking(@project)
     check_cards_in_list_view(@release1, @iteration2)
     click_edit_properties_button
     set_bulk_properties(@project, 'Type' => @type_story.name)

     navigate_to_tree_view_for(@project,@planning_tree.name)
     assert_first_level_node @release1
     assert_first_level_node @iteration2
     assert_first_level_node @iteration1
     assert_first_level_node @release2
     assert_parent_node @iteration1, @story1
     assert_parent_node @release2, story2
   end

  #5343
   def test_can_drag_a_card_from_search_results_to_tree_again_after_remove_it_from_tree
     @browser.run_once_full_text_search
     add_cards_to_get_a_basic_RIS_tree
     navigate_to_tree_view_for(@project,@planning_tree.name)
     search_through_card_explorer_text_search('iteration')
     assert_candidate_card_is_draggable_in_search(@iteration2)
     add_card_to_tree(@planning_tree, @iteration2, @release1)
     search_through_card_explorer_text_search('iteration')
     assert_candidate_card_is_not_draggable_in_search(@iteration2)
     select_tree(@planning_tree.name)
     click_remove_link_for_card(@iteration2)
     search_through_card_explorer_text_search('iteration')
     assert_candidate_card_is_draggable_in_search(@iteration2)
   end

   #bug 5250
   def test_I_should_not_see_confirm_box_if_I_delete_a_tree_node_without_any_children
     add_cards_to_get_a_basic_RIS_tree
     add_card_to_tree(@planning_tree, @iteration2, @release1)
     navigate_to_tree_view_for(@project, @planning_tree.name)
     click_remove_link_for_card(@iteration1)
     assert_confirm_box_for_remove_tree_node_present
     click_cancel_remove_from_tree
     drag_and_drop_card_in_tree(@iteration2, @story1)
     click_remove_link_for_card(@iteration2)
     assert_confirm_box_for_remove_tree_node_present
     click_cancel_remove_from_tree
     click_remove_link_for_card(@iteration1)
     assert_cards_not_showing_on_tree(@iteration1)
     root = @planning_tree.create_tree.root
     drag_and_drop_card_in_tree(root, @story1)
     click_remove_link_for_card(@iteration2)
     assert_cards_not_showing_on_tree(@iteration2)
   end

   #bug 5389
   def test_adding_new_cards_in_tree_view_will_overwrite_card_default
     open_edit_defaults_page_for(@project, STORY)
     set_property_defaults(@project, ITERATION_PROPERTY => @iteration1)
     navigate_to_tree_view_for(@project, PLANNING_TREE)
     quick_add_cards_on_tree(@project, @planning_tree, :root, :card_names => ['story'], :type => STORY)
     card = @project.cards.find_by_name('story')
     open_card(@project, card)
     assert_properties_not_set_on_card_show(ITERATION_PROPERTY)
   end

   def test_card_link_on_mini_card
     add_cards_to_get_a_basic_RIS_tree
     navigate_to_tree_view_for(@project, @planning_tree.name)
     assert_link_present_on_mini_card(@release1)
     assert_tooltip_for_mini_card_link_present
     open_card_via_clicking_link_on_mini_card(@release1)
     assert_card_name_in_show(@release1.name)
   end

   def test_card_link_on_mini_card_on_maxmise_tree_view
     add_cards_to_get_a_basic_RIS_tree
     navigate_to_tree_view_for(@project, @planning_tree.name)
     maximize_current_view
     assert_link_present_on_mini_card(@release1)
     open_card_via_clicking_link_on_mini_card(@release1)
     assert_card_name_in_show(@release1.name)
   end

   private
   def add_cards_to_get_a_basic_RIS_tree
     add_card_to_tree(@planning_tree, @release1)
     add_card_to_tree(@planning_tree, @iteration1, @release1)
     add_card_to_tree(@planning_tree, @story1, @iteration1)
   end

end
