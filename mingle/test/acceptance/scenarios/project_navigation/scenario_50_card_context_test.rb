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

# Tags: scenario, navigation, card-list, cards
class Scenario50CardContextTest < ActiveSupport::TestCase

  fixtures :users, :login_access
  
  DEFECT = 'defect'
  STORY = 'story'
  LITTLE_CARD = 'little_card'
  FEATURE = 'feature'
  STATUS = 'Status'
  NEW = 'new'
  OPEN = 'open'
  CLOSED = 'CLOSED'
  ITERATION = 'iteration'
  Mytree = 'Mytree'
  TREE = 'tree'
  TREE_STORY = 'tree_story'
  TREE_DEFECT = 'tree_defect'
  TREE_LITTLE_CARD = 'tree_little_card'
  TREE_FEATURE = 'tree_feature'
  CONTENT = 'content'
  DETAILS = 'details'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)    
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_50', :users => [users(:admin)])
    setup_property_definitions(STATUS => [NEW, OPEN, CLOSED], ITERATION => [1, 2])
    setup_property_definitions(CONTENT => [10,20,30])
    setup_property_definitions(DETAILS => [50,60])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [STATUS])
    @type_story = setup_card_type(@project, STORY, :properties => [STATUS, ITERATION])
    @type_little_card = setup_card_type(@project,LITTLE_CARD, :properties => [CONTENT])
    @type_feature = setup_card_type(@project, FEATURE, :properties => [DETAILS])
    login_as_admin_user
    open_project(@project)
    @story1 = create_card!(:name => 'story card1', :card_type => @type_story.name)
    @story2 = create_card!(:name => 'story card2', :card_type => @type_story.name)
    @story3 = create_card!(:name => 'story card3', :card_type => @type_story.name)
    @story4 = create_card!(:name => 'story card4', :card_type => @type_story.name)
    @defect1 = create_card!(:name => 'defect card1', :card_type => @type_defect.name)
    @defect2 = create_card!(:name => 'defect card2', :card_type => @type_defect.name)
    @defect3 = create_card!(:name => 'defect card3', :card_type => @type_defect.name)
    @defect4 = create_card!(:name => 'defect card4', :card_type => @type_defect.name)
    @defect5 = create_card!(:name => 'defect card5', :card_type => @type_defect.name)
    @defect6 = create_card!(:name => 'defect card6', :card_type => @type_defect.name)
    @defect7 = create_card!(:name => 'defect card7', :card_type => @type_defect.name)
    @defect8 = create_card!(:name => 'defect card8', :card_type => @type_defect.name)
    @card1 = create_card!(:name => 'little card1', :card_type  => @type_little_card.name)
    @card2 = create_card!(:name => 'little card2', :card_type  => @type_little_card.name)
    @card3 = create_card!(:name => 'little card3', :card_type  => @type_little_card.name)
    @feature1 = create_card!(:name => 'feature1', :card_type => @type_feature.name)
    @tree = setup_tree(@project, TREE, :types => [@type_story, @type_defect,@type_little_card, @type_feature], :relationship_names => [TREE_STORY, TREE_DEFECT, TREE_LITTLE_CARD, TREE_FEATURE])
  end
  
  def teardown
    @project.deactivate
  end

  def test_open_card_from_hierarchy_view_display_context
    add_card_to_tree(@tree, @story1)
    add_card_to_tree(@tree, @defect1, @story1)
    add_card_to_tree(@tree, @story2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@story1)
    click_card_on_hierarchy_list(@story2)
    assert_card_name_in_show(@story2.name)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 3)
  end
  
  def test_card_context_will_display_cards_in_Detpth_First_Traverse_order
    add_card_to_tree(@tree, @story1)
    add_card_to_tree(@tree,[@defect1,@defect2], @story1)
    add_card_to_tree(@tree, [@card1, @card2], @defect2)
    add_card_to_tree(@tree, @feature1, @card2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@story1, @defect2, @card2)
    click_card_on_hierarchy_list(@story1)
    click_next_link
    click_next_link
    click_next_link
    assert_card_context_present
    assert_context_text(:this_is => 4, :of => 6)
    assert_card_name_in_show(@feature1.name)
  end
  
  
  def test_user_should_goes_through_the_cards_via_card_context_with_the_same_order_in_hierachy_view
    add_card_to_tree(@tree, @story1)
    add_card_to_tree(@tree, @story2)
    add_card_to_tree(@tree, @story3)
    add_card_to_tree(@tree, @story4)
    add_card_to_tree(@tree,[@defect1,@defect2], @story1)
    add_card_to_tree(@tree, @defect3, @story2)
    add_card_to_tree(@tree, @defect4, @story3)
    add_card_to_tree(@tree,[@defect5,@defect6,@defect7,@defect8], @story4)
    add_card_to_tree(@tree,[@card1,@card2], @defect1)
    add_card_to_tree(@tree, @card3, @defect2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@story1, @story2, @story3, @story4, @defect1, @defect2)
    click_card_on_hierarchy_list(@story4)
    assert_card_name_in_show(@story4.name)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 15)
    click_next_link
    assert_card_name_in_show(@defect8.name)

    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@story1, @story2, @story3, @story4, @defect1, @defect2)
    
    click_card_on_hierarchy_list(@story1)
    assert_card_name_in_show(@story1.name)
    assert_card_context_present
    assert_context_text(:this_is => 10, :of => 15)
    click_next_link
    assert_card_name_in_show(@defect2.name)
    assert_card_context_present
    assert_context_text(:this_is => 11, :of => 15)
    click_next_link
    assert_card_name_in_show(@card3.name)
    assert_card_context_present
    assert_context_text(:this_is => 12, :of => 15)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@story1, @story2, @story3, @story4, @defect1, @defect2)
    click_card_on_hierarchy_list(@story3)
    click_next_link
    click_next_link
    assert_card_name_in_show(@story2.name)    
  end
  
  def test_card_context_should_not_include_the_cards_that_not_shown_in_hierachy_view
    add_card_to_tree(@tree, @story1)
    add_card_to_tree(@tree, @story2)
    add_card_to_tree(@tree, @story3)
    add_card_to_tree(@tree, @story4)
    add_card_to_tree(@tree,[@defect1,@defect2], @story1)
    add_card_to_tree(@tree, @defect3, @story2)
    add_card_to_tree(@tree, @defect4, @story3)
    add_card_to_tree(@tree,[@defect5,@defect6,@defect7,@defect8], @story4)
    add_card_to_tree(@tree,[@card1,@card2], @defect1)
    add_card_to_tree(@tree, @card3, @defect2)
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@story1, @story2, @story3, @story4, @defect1, @defect2)

    click_exclude_card_type_checkbox(@type_little_card)
    
    
    click_card_on_hierarchy_list(@story4) 
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 12)
    click_up_link
    click_card_on_hierarchy_list(@story1)
    assert_card_context_present
    assert_context_text(:this_is => 10, :of => 12)
    click_next_link
    assert_card_name_in_show(@defect2.name)
    assert_card_context_present
    assert_context_text(:this_is => 11, :of => 12)
    click_next_link
    assert_card_name_in_show(@defect1.name)
    assert_card_context_present
    assert_context_text(:this_is => 12, :of => 12)
  end
  
  def test_card_opened_from_list_displays_context
    cards = create_cards(@project, 4)
    navigate_to_card_list_for(@project)
    click_card_on_list(cards[3])
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 20)
  end
  
  def test_context_not_present_when_opening_card_from_history_version
    cards = create_cards(@project, 3)
    @browser.run_once_history_generation
    open_card_for_edit(@project, cards[1].number)
    type_card_name('new name')
    save_card
    navigate_to_history_for(@project)
    click_history_version_link_for(:card_number => 18, :version_number => 1)
    assert_card_context_not_present
    navigate_to_history_for(@project)
    click_history_version_link_for(:card_number => 18, :version_number => 2)
    assert_card_context_not_present
  end
  
  def test_context_not_present_when_opening_card_from_link_on_wiki_page
    cards = create_cards(@project, 2)
    link_to_card = "##{cards[0].number}"
    page_name = 'foo'
    create_new_wiki_page(@project, page_name, "#{link_to_card}")
    with_ajax_wait { open_wiki_page(@project, page_name) }
    click_link(link_to_card)
    assert_card_context_not_present
  end
  
  def test_context_not_present_on_card_edit_page
    cards = create_cards(@project, 3)
    open_card_for_edit(@project, cards[2].number)
    assert_card_context_not_present
  end
  
  def test_context_not_present_when_opening_link_to_a_card_outside_of_context
    story_one = create_card!(:name => 'story one', :card_type => STORY)
    link_to_story_one = "##{story_one.number}"
    defect_one = create_card!(:name => 'bug one', :card_type => DEFECT, :description => "releated to story #{link_to_story_one}")
    defect_two = create_card!(:name => 'bug two', :card_type => DEFECT, STATUS => NEW)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => DEFECT)
    click_card_on_list(defect_one)
    assert_card_context_present
    assert_context_text(:this_is => 2, :of => 10)
    click_link(link_to_story_one)
    assert_card_context_not_present
  end
  
  def test_context_present_when_opening_via_link_in_another_card_in_same_context
    defect_one = create_card!(:name => 'bug one', :card_type => DEFECT)
    defect_two = create_card!(:name => 'bug two', :card_type => DEFECT, STATUS => NEW)
    link_to_defect_two = "##{defect_two.number}"
    defect_three = create_card!(:name => 'bug three', :card_type => DEFECT, STATUS => NEW, :description => "related to other new defect #{link_to_defect_two}")
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => DEFECT, STATUS => NEW)
    click_card_on_list(defect_three)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 2)
    click_link(link_to_defect_two)
    assert_card_context_present
    assert_context_text(:this_is => 2, :of => 2)
  end
  
  def test_card_stays_in_same_context_after_changing_property_value_that_places_it_in_that_context
    closed_defect = create_card!(:name => 'bug one', :card_type => DEFECT, STATUS => CLOSED)
    new_defect = create_card!(:name => 'bug two', :card_type => DEFECT, STATUS => NEW)
    new_defect_to_be_changed_to_story = create_card!(:name => 'bug three', :card_type => DEFECT, STATUS => NEW)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => DEFECT, STATUS => NEW)
    collapse_and_expand_side_bar
    #@browser.click('sidebar-control')
    new_defects_view_name = 'new defect'
    create_card_list_view_for(@project, new_defects_view_name)
    click_card_on_list(new_defect_to_be_changed_to_story)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 2)
    set_card_type_on_card_show(STORY)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 2)
    open_card(@project, closed_defect.number)
    click_link(new_defects_view_name)
    click_card_on_list(new_defect)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 1)
  end
    
  def test_clicking_previous_and_next_links_stays_in_correct_card_context
    new_story_one = create_card!(:name => 'new story one', :card_type => STORY, STATUS => NEW)
    closed_story_one = create_card!(:name => 'closed story', :card_type => STORY, STATUS => CLOSED)
    new_story_two = create_card!(:name => 'new story two', :card_type => STORY, STATUS => NEW)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, STATUS => NEW)
    
    click_card_on_list(new_story_two)
    assert_card_context_present
    assert_context_text(:this_is => 1, :of => 2)
    
    click_next_link
    assert_card_name_not_in_show(closed_story_one.name)
    assert_card_name_in_show(new_story_one.name)
    
    click_previous_link
    assert_card_name_not_in_show(closed_story_one.name)
    assert_card_name_in_show(new_story_two.name)
  end
  
  
  
  # bug 4435
  def test_should_not_loose_card_context_while_collapse_and_expand_side_bar
    cards = create_cards(@project, 4)
    navigate_to_card_list_for(@project)
    click_link(cards[3].name)
    collapse_and_expand_side_bar
    click_next_card_on_card_context
    assert_card_context_present
    assert_context_text(:this_is => 2, :of => 20)
  end
  
  
  # bug 5638
  def test_card_context_of_list_and_hierarchy_view_should_work_independently
    add_card_to_tree(@tree, @story1)
    add_card_to_tree(@tree, @story2) 
    add_card_to_tree(@tree, @defect1, @story2)
      
    navigate_to_card_list_for(@project)
    select_tree @tree.name
    
    click_link(@story2.name)
    assert_card_name_in_show(@story2.name)
    click_next_card_on_card_context
    assert_card_name_in_show(@story1.name)
      
    navigate_to_hierarchy_view_for(@project, @tree)
    click_twisty_for(@story2)
    click_card_on_hierarchy_list(@story2)
    assert_card_name_in_show(@story2.name)
    click_next_card_on_card_context
    assert_card_name_in_show(@defect1.name)   
  end
  
end
