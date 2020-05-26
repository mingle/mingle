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

#Tags: tree-usage

class Scenario127CollapseExpandOnTreeViewTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  
  RELEASE = "Release"
  ITERATION = "Iteration"
  STORY = "Story"
  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_127', :admins => [users(:proj_admin)])
    @project.activate
    
    @release_type = setup_card_type(@project, RELEASE)
    @iteration_type = setup_card_type(@project, ITERATION)
    @story_type = setup_card_type(@project, STORY)
     
    @tree = setup_tree(@project, 'R-I-S tree', :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["Release", "Iteration"])
    login_as_proj_admin_user
  end
  
  def test_tree_nodes_should_be_able_to_expanded_or_collapsed
    create_some_cards_and_added_onto_tree
    @browser.open("/projects/#{@project.identifier}/cards/tree?tab=All&tree_name=#{@tree.name}")
    assert_nodes_collapsed_in_tree_view(@releases[0], @releases[1])
    assert_card_not_present_on_tree(@iterations[0], @iterations[1], @stories[0], @stories[1])
   
    expand_collapse_nodes_in_tree_view(@releases[0], @iterations[0])
    assert_nodes_expanded_in_tree_view(@releases[0], @iterations[0])
    assert_cards_on_a_tree(@iterations[0], @stories[0])

    expand_collapse_nodes_in_tree_view(@releases[0])
    assert_nodes_collapsed_in_tree_view(@releases[0])
    assert_card_not_present_on_tree(@iterations[0], @stories[0])
  end
  
  def test_remember_the_expand_collapse_state_on_changing_filter
    create_some_cards_and_added_onto_tree
    @browser.open("/projects/#{@project.identifier}/cards/tree?tab=All&tree_name=#{@tree.name}")
    expand_collapse_nodes_in_tree_view(@releases[0], @iterations[0])
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
    
    click_exclude_card_type_checkbox(RELEASE)
    assert_nodes_collapsed_in_tree_view(@iterations[1])
    assert_nodes_expanded_in_tree_view(@iterations[0])
    
    click_exclude_card_type_checkbox(RELEASE)
    click_exclude_card_type_checkbox(ITERATION)
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@releases[0])
    
    click_exclude_card_type_checkbox(ITERATION)
    set_tree_filter_for(@release_type, 0, :property => RELEASE, :value => @releases[0].number)
    assert_card_not_present_on_tree(@releases[1], @iterations[1], @stories[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
  end
  
  
  def test_remember_the_expand_collapse_state_on_swithing_views
    create_some_cards_and_added_onto_tree
    @browser.open("/projects/#{@project.identifier}/cards/tree?tab=All&tree_name=#{@tree.name}")
    expand_collapse_nodes_in_tree_view(@releases[0], @iterations[0])
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
       
    switch_to_grid_view
    switch_to_tree_view    
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
    
    select_tree('None')
    select_tree(@tree.name)
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
    
    click_overview_tab
    click_all_tab
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
  end
  
  def test_saved_view_should_remember_the_expand_collapse_status
    create_some_cards_and_added_onto_tree
    @browser.open("/projects/#{@project.identifier}/cards/tree?tab=All&tree_name=#{@tree.name}")
    expand_collapse_nodes_in_tree_view(@releases[0], @iterations[0])
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
    
    saved_view = create_card_list_view_for(@project, "tree view")
    expand_collapse_nodes_in_tree_view(@iterations[0], @releases[0])
    expand_collapse_nodes_in_tree_view(@releases[1], @iterations[1])
    assert_nodes_collapsed_in_tree_view(@releases[0])
    assert_nodes_expanded_in_tree_view(@iterations[1], @releases[1])
    open_saved_view(saved_view.name)
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
  end
  
  def test_tree_and_hierarchy_view_expand_collapse_status_should_keep_consistent
    create_some_cards_and_added_onto_tree
    @browser.open("/projects/#{@project.identifier}/cards/tree?tab=All&tree_name=#{@tree.name}")
    expand_collapse_nodes_in_tree_view(@releases[0], @iterations[0])
    assert_nodes_collapsed_in_tree_view(@releases[1])
    assert_nodes_expanded_in_tree_view(@iterations[0], @releases[0])
    
    switch_to_hierarchy_view
    click_twisty_for(@iterations[0], @releases[0], @releases[1], @iterations[1])
    switch_to_tree_view
    assert_nodes_collapsed_in_tree_view(@releases[0])
    assert_nodes_expanded_in_tree_view(@iterations[1], @releases[1])  
  end

  private
  def create_some_cards_and_added_onto_tree
    @releases = create_cards(@project, 2, :card_type => @release_type)
    @iterations = create_cards(@project, 2, :card_type => @iteration_type)  
    @stories = create_cards(@project, 2, :card_type => @story_type)

    add_card_to_tree(@tree, @releases[0])
    add_card_to_tree(@tree, @releases[1])
    add_card_to_tree(@tree, @iterations[0], @releases[0])
    add_card_to_tree(@tree, @iterations[1], @releases[1])
    add_card_to_tree(@tree, @stories[0], @iterations[0])
    add_card_to_tree(@tree, @stories[1], @iterations[1])
  end
end
