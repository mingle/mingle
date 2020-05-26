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

# Tags: bulk, tagging, cards
class Story2763RemoveCardFromTreeOnCardView < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  RELEASE = 'release'
  ITERATION = 'iteration'
  STORY = 'story'
  
  PLANNING_TREE_RELEASE = 'planning tree - release'
  PLANNING_TREE_ITERATION = 'planning tree - iteration'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'story_2763', :users => [@non_admin_user], :admins => [@project_admin_user, users(:admin)])

    @type_release = setup_card_type(@project, RELEASE)
    @type_iteration = setup_card_type(@project, ITERATION)
    @type_story = setup_card_type(@project, STORY)
    login_as_admin_user
    @tree = setup_tree(@project, 'planning tree', :types => [@type_release, @type_iteration, @type_story],
      :relationship_names => [PLANNING_TREE_RELEASE, PLANNING_TREE_ITERATION])
    @release1 = create_card!(:name => 'release 1', :card_type => RELEASE)
    @iteration1 = create_card!(:name => 'iteration 1', :card_type => ITERATION)
    @story1 = create_card!(:name => 'story 1', :card_type => STORY)
  end
  
  def test_should_not_show_remove_card_from_tree_link_when_card_does_not_belong_to_tree
    open_card(@project, @release1)
    assert_card_available_to_tree_message_present_for(@tree)
    assert_remove_card_from_tree_link_is_not_present(@tree)
  end
  
  def test_acceptance_criteria_1_deleting_cards_without_parents_or_children_view_release_1_card_view
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added at the root.
    # add_card_to_tree(@tree, @release1)
    add_cards_to_tree(@tree, :root, @release1, @iteration1, @story1)
    
    # When: View Release 1 card view.
    open_card(@project, @release1)
    
    # Then: Card view shows from Planning tree and (This card belongs to this tree). No relationship properties are shown. Card view shows way to
    # delete Release 1 from 'Planning' tree.
    assert_card_belongs_to_tree_message_present_for(@tree)
    assert_remove_card_from_tree_link_is_visible(@tree)
  end
  
  def test_acceptance_criteria_2_deleting_cards_without_parents_or_children_view_story_1_card_view_when_on_root
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added at the root.
    add_cards_to_tree(@tree, :root, @release1, @iteration1, @story1)
    
    # When: View Release 1 card view.
    open_card(@project, @story1)
    
    # Then: Card view shows from Planning tree and (This card belongs to this tree). No relationship properties are shown. Card view shows way to
    # delete Release 1 from 'Planning' tree.
    assert_card_belongs_to_tree_message_present_for(@tree)
    assert_remove_card_from_tree_link_is_visible(@tree)
  end
  
  def test_acceptance_criteria_3_deleting_cards_without_parents_or_children_delete_release_1_card_from_tree_from_card_view
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added at the root. Card view for Release 1 card shows from Planning tree and (This card belongs to this tree). No relationship properties are shown.
    add_cards_to_tree(@tree, :root, @release1, @iteration1, @story1)
    
    # When: Delete Release 1 card from tree from card view.
    open_card(@project, @release1)
    click_remove_from_tree_and_wait_for_card_to_be_removed(@tree)
    
    # Then: Release 1 is no longer part of 'Planning' tree. Iteration 1 and Story 1 are still members of the 'Planning' tree. Card view for Release 1 card shows from Planning tree and (This card is available to this tree.). No relationship properties are shown. Release 1 can no longer be deleted from tree.
    assert_all_cards_in_tree(@iteration1, @story1)
    assert_card_available_to_tree_message_present_for(@tree)
    assert_remove_card_from_tree_link_is_not_present(@tree)
  end
  
  def test_acceptance_criteria_4_deleting_cards_without_parents_or_children_delete_story_1_card_from_tree_from_card_view
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added at the root. Card view for Story 1 card shows from Planning tree and (This card belongs to this tree). Relationship properties 'Release' and 'Iteration' are set to (not set).
    add_cards_to_tree(@tree, :root, @release1, @iteration1, @story1)
    
    # When: Delete Story 1 card from tree from card view.
    open_card(@project, @story1)
    click_remove_from_tree_and_wait_for_card_to_be_removed(@tree)
    
    # Then: Story 1 is no longer part of 'Planning' tree. Release 1 and Iteration 1 are still members of the 'Planning' tree. Card view for Story 1 card shows from Planning tree and (This card is available to this tree.). Relationship properties are shown as (not set). Story 1 can no longer be deleted from tree.
    assert_all_cards_in_tree(@release1, @iteration1)
    assert_card_available_to_tree_message_present_for(@tree)
    assert_remove_card_from_tree_link_is_not_present(@tree)
  end
  
  def test_acceptance_criteria_10_deleting_cards_with_parent_cards_delete_story_1_card_from_tree_from_card_view
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added. Release 1 and Iteration 1 have been added at the root. Story 1 is a child of Iteration 1.
    add_cards_to_tree(@tree, :root, 
                               @release1, 
                               @iteration1, [
                                 @story1])
    
    # When: Delete Story 1 card from tree from card view.
    open_card(@project, @story1)
    click_remove_from_tree_and_wait_for_card_to_be_removed(@tree)
    
    # Then: Story 1 no longer belongs to 'Planning tree'. Release 1 and Iteration 1 are still members of the 'Planning' tree. Card view for Story 1 card shows from Planning tree and (This card is available to this tree.). Relationship properties are shown as (not set).
    assert_all_cards_in_tree(@release1, @iteration1)
    assert_remove_card_from_tree_link_is_not_present(@tree)
    assert_properties_not_set_on_card_show(PLANNING_TREE_RELEASE, PLANNING_TREE_ITERATION)
  end
  
  def test_acceptance_criteria_20_deleting_cards_with_children_select_to_delete_iteration_1_card_from_tree_from_card_view
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added. Release 1 and Iteration 1 have been added at the root. Story 1 is a child of Iteration 1.
    add_cards_to_tree(@tree, :root, 
                               @release1, 
                               @iteration1, [
                                  @story1])
    
    # When: Select to delete Iteration 1 card from tree from card view.
    open_card(@project, @iteration1)
    click_remove_from_tree(@tree)
    
    # Then: User is prompted "Remove this card's children as well?" with options "This card & its children", "Just this card" and "Cancel".
    @browser.assert_text_present "Remove this card's children as well?"
    @browser.assert_button_text_present(THIS_CARD_AND_ITS_CHILDREN)
    @browser.assert_button_text_present(JUST_THIS_CARD)
    @browser.assert_button_text_present(CANCEL)
  end
  
  def test_acceptance_criteria_21_deleting_cards_with_children_user_selects_to_delete_this_card_and_its_children
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added. Release 1 and Iteration 1 have been added at the root. Story 1 is a child of Iteration 1. User selects to delete Iteration 1 card from tree from card view and is prompted.
    add_cards_to_tree(@tree, :root, 
                               @release1, 
                               @iteration1, [
                                 @story1])
    open_card(@project, @iteration1)
    click_remove_from_tree(@tree)
    
    # When: User selects to delete "This card & its children".
    click_remove_this_card_and_its_children
    
    # Then: Iteration 1 and Story 1 are no longer members of the 'Planning' tree. Release 1 is still a member of the 'Planning' tree.
    assert_all_cards_in_tree(@release1)
    # Card view for Iteration 1 card shows from Planning tree and (This card is available to this tree). Relationship properties are shown as (not set).
    assert_card_available_to_tree_message_present_for(@tree)
    assert_properties_not_set_on_card_show(PLANNING_TREE_RELEASE)
    # Card view for Story 1 card shows from Planning tree and (This card is available to this tree.). Relationship properties are shown as (not set).
    open_card(@project, @story1)
    assert_card_available_to_tree_message_present_for(@tree)
    assert_properties_not_set_on_card_show(PLANNING_TREE_RELEASE, PLANNING_TREE_ITERATION)
  end
  
  def test_acceptance_criteria_22_deleting_cards_with_children_user_selects_to_delete_just_this_card
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added. Release 1 and Iteration 1 have been added at the root. Story 1 is a child of Iteration 1. User select to delete Iteration 1 card from tree from card view and is prompted.
    add_cards_to_tree(@tree, :root, 
                               @release1, 
                               @iteration1, [
                                 @story1])
    open_card(@project, @iteration1)
    click_remove_from_tree(@tree)
    
    # When: User selects to delete "Just this card".
    click_remove_just_this_card
    
    # Then: Iteration 1 is no a longer a member of the 'Planning' tree. Release 1 and Story 1 are still members of the 'Planning' tree.
    @story1.reload
    assert_all_cards_in_tree(@release1, @story1)
    # Story 1 is now a member at the root node.
    assert @tree.find_all_ancestor_cards(@story1).empty?
    # Card view for Iteration 1 card shows from Planning tree and (This card is available to this tree). Relationship properties are shown as (not set).
    assert_card_available_to_tree_message_present_for(@tree)
    assert_properties_not_set_on_card_show(PLANNING_TREE_RELEASE)
    # Card view for Story 1 card shows from Planning tree and (This card belongs to this tree). Relationship properties are shown as (not set). Story 1 cannot be deleted.
    open_card(@project, @story1)
    assert_card_belongs_to_tree_message_present_for(@tree)
    assert_properties_not_set_on_card_show(PLANNING_TREE_RELEASE, PLANNING_TREE_ITERATION)
  end
  
  def test_acceptance_criteria_23_deleting_cards_with_children_user_selects_cancel
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added. Release 1 and Iteration 1 have been added at the root. Story 1 is a child of Iteration 1. User select to delete Iteration 1 card from tree from card view and is prompted.
    add_cards_to_tree(@tree, :root, 
                               @release1, 
                               @iteration1, [
                                 @story1])
    open_card(@project, @iteration1)
    click_remove_from_tree(@tree)
    
    # When: User selects "Cancel".
    click_cancel_remove_from_tree
    
    # Then: No cards are removed from the tree. User is returned to card view of Iteration 1. Release 1, Iteration 1 and Story 1 are still members of the 'Planning' tree.
    assert_all_cards_in_tree(@release1, @iteration1, @story1)
    assert_on_card(@project, @iteration1)
  end
  
  def test_acceptance_criteria_30_deleting_cards_with_parents_and_children_user_selects_to_delete_this_card_and_its_children
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added. Release 1 has been added at the root. Iteration 1 is a child of Release 1. Story 1 is a child of Iteration 1. Users select to delete Iteration 1 card from tree from card view and is prompted.
    add_cards_to_tree(@tree, @release1, [
                               @iteration1, [
                                 @story1]])
    open_card(@project, @iteration1)
    click_remove_from_tree(@tree)
    
    # When: User selects to delete "This card & its children".
    click_remove_this_card_and_its_children
    
    # Then: Iteration 1 and Story 1 are removed from the tree. Release 1 is still a member of the tree.
    assert_all_cards_in_tree(@release1)
  end
  
  def test_acceptance_criteria_31_deleting_cards_with_parents_and_children_user_selects_to_delete_just_this_card
    # Given: 'Planning' tree has been created - Release -> Iteration -> Story and has Release 1, Iteration 1 and Story 1 cards added. Release 1 has been added at the root. Iteration 1 is a child of Release 1. Story 1 is a child of Iteration 1. Users select to delete Iteration 1 card from tree from card view and is prompted.
    add_cards_to_tree(@tree, @release1, [
                               @iteration1, [
                                 @story1]])
    open_card(@project, @iteration1)
    click_remove_from_tree(@tree)
    
    # When: User selects to delete "Just this card".
    click_remove_just_this_card
    
    # Then: Iteration 1 is removed from the tree. Release 1 and Story 1 are still members of the tree.
    @story1.reload
    assert_all_cards_in_tree(@release1, @story1)
    # Card view for Iteration 1 card shows from Planning tree and (This card is available to this tree). Relationship properties are shown as (not set).
    assert_card_available_to_tree_message_present_for(@tree)
    assert_properties_not_set_on_card_show(PLANNING_TREE_RELEASE)
    # Card view for Story 1 card shows from Planning tree and (This card belongs to this tree). Relationship properties for 'Iteration' is shown as (not set). Relationship property for Release is 'Release 1'. Story 1 cannot be deleted.
    open_card(@project, @story1)
    assert_card_belongs_to_tree_message_present_for(@tree)
    assert_properties_not_set_on_card_show(PLANNING_TREE_ITERATION)
    assert_property_set_to_card_on_card_show(PLANNING_TREE_RELEASE, @release1)
  end
  
  def test_removing_card_from_tree_should_retain_transitions
    add_card_to_tree(@tree, @release1)
    setup_property_definitions :status => ['open', 'closed']
    transition = create_transition(@project, 'close the card', :set_properties => {:status => 'closed'})
    assert transition.available_to?(@release11)
    open_card(@project, @release1)
    click_remove_from_tree_and_wait_for_card_to_be_removed(@tree)
    assert_transition_present_on_card(transition)
  end
  
  def test_removing_card_from_tree_should_retain_context
    add_cards_to_tree(@tree, @release1, [
                               @iteration1, [
                                 @story1]])
    navigate_to_tree_view_for(@project, @tree.name)
    open_card(@project, @iteration1)
    assert_context_text(:this_is => 2, :of => 3)
    click_remove_from_tree(@tree)
    click_remove_just_this_card
    assert_context_text(:this_is => 2, :of => 3)
    click_previous_link
    assert_context_text(:this_is => 1, :of => 3)
    click_next_link
    assert_context_text(:this_is => 2, :of => 3)
  end
  
  private
  def assert_all_cards_in_tree(*cards)
    assert_equal cards.smart_sort_by(&:id), @tree.create_tree.nodes_without_root.smart_sort_by(&:id)
  end
end
