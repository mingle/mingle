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

#Tags: tree-usage, search

class Scenario66CardTreeExplorerTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  PRIORITY = 'riority'
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

  NOTSET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  LOW = 'low'

  PLANNING = 'Planning'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_admin_user = users(:longbob)
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_66', :users => [@non_admin_user], :admins => [@project_admin_user])
    setup_property_definitions(PRIORITY => ['high', LOW], SIZE => [1, 2, 4], STATUS => [NEW,  'close', OPEN], ITERATION => [1,2,3,4], OWNER  => ['a', 'b', 'c'])
    @type_story = setup_card_type(@project, STORY, :properties => [PRIORITY, SIZE, ITERATION, OWNER])
    @type_defect = setup_card_type(@project, DEFECT, :properties => [PRIORITY, STATUS, OWNER])
    @type_task = setup_card_type(@project, TASK, :properties => [PRIORITY, SIZE, ITERATION, STATUS, OWNER])
    @type_iteration = setup_card_type(@project, ITERATION_TYPE)
    @type_release = setup_card_type(@project, RELEASE)
    login_as_proj_admin_user
    @r1 = create_card!(:name => 'release 1 marketplace', :description => "Without software, most organizations could not survive in the current marketplace see bug100", :card_type => RELEASE)
    @r2 = create_card!(:name => 'release 2', :card_type => RELEASE)
    @i1 = create_card!(:name => 'iteration 1', :card_type => ITERATION_TYPE)
    @i2 = create_card!(:name => 'iteration 2', :card_type => ITERATION_TYPE)
    @tree = setup_tree(@project, 'Planning2', :types => [@type_release, @type_iteration, @type_story], :relationship_names => ['Planning Tree release', 'Planning Tree iteration'])
    add_card_to_tree(@tree, @r1)
    navigate_to_tree_configuration_management_page_for(@project)
  end

  def test_card_tree_text_search_searches_all_cards_that_match_search_critaria
    search_strings_with_results = [ ['MARkeTPlace', '1']] #, ['1', '4']] #todo: we need decide what it should return for a single number. For now its a time bomb which will make this test failed on every days in January or first day of each month
    search_strings_which_gives_no_result = ['xyz']
    create_cards(@project, 10, :card_type => @type_story, :card_name => 'funny things card')
    create_cards(@project, 10, :card_type => @type_task, ITERATION => '1')
    create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE, STORY, TASK])
    assert_notice_message('Card tree was successfully created')
    wait_for_tree_result_load  
    @browser.run_once_full_text_search   
    navigate_to_tree_view_for(@project, PLANNING)
    search_strings_with_results.each do |search_string, count|
      search_through_card_explorer_text_search(search_string)
      assert_count_of_cards_should_be_in_search_result(count, search_string)
    end
    search_strings_which_gives_no_result.each do |search_string|
      search_through_card_explorer_text_search(search_string)
      assert_no_match_found_for_the_tree_for(search_string)
    end
  end

  def test_search_results_through_card_explorer_text_search_are_enabled_for_drag_and_drop
    create_and_configure_new_card_tree(@project, :name => PLANNING, :types => [RELEASE, ITERATION_TYPE])
    assert_notice_message('Card tree was successfully created')
    @browser.run_once_full_text_search   
    navigate_to_tree_view_for(@project, PLANNING)
    search_string = 'release'
    search_through_card_explorer_text_search(search_string)
    assert_count_of_cards_should_be_in_search_result('2', search_string)
    assert_searched_cards_enabled_for_drag(@r1)
    assert_searched_cards_enabled_for_drag(@r2)
  end

  def test_search_results_through_card_explorer_text_search_are_enabled_only_if_not_used_by_tree
    @browser.run_once_full_text_search   
    navigate_to_tree_view_for(@project, "planning2")
    search_string = 'release'
    search_through_card_explorer_text_search(search_string)
    assert_count_of_cards_should_be_in_search_result('2', search_string)
    assert_searched_cards_disabled_for_drag(@r1)
    assert_searched_cards_enabled_for_drag(@r2)
    assert_cards_on_a_tree(@project, @r1)
  end

  def test_search_results_are_valid_cards_for_tree_configuration
    setup_tree(@project, 'bugfix plan', :types => [@type_release, @type_iteration, @type_defect], :relationship_names => ['bugfix plan release', 'bugfix plan iteration'])
    bug_card = create_card!(:name => 'bug100', :card_type => DEFECT)
    story_card = create_card!(:name => 'bug100 changed to story', :card_type => STORY)
    @browser.run_once_full_text_search   
    navigate_to_tree_view_for(@project, 'bugfix plan')
    search_through_card_explorer_text_search('bug100')
    assert_searched_cards_enabled_for_drag(bug_card)
    assert_card_not_present_in_search_result(story_card)
    navigate_to_tree_view_for(@project, 'Planning2')
    search_through_card_explorer_text_search('bug100')
    assert_card_not_present_in_search_result(bug_card)
    assert_card_present_in_search_result(story_card)
  end

  # bug 3678
  def test_can_search_for_card_with_hash_symbol_and_card_number
    tree = setup_tree(@project, 'bugfix plan', :types => [@type_release, @type_iteration, @type_defect], :relationship_names => ['bugfix plan release', 'bugfix plan iteration'])
    bug_card = create_card!(:name => 'bug100', :card_type => DEFECT)
    add_card_to_tree(tree, @r1)
    @browser.run_once_full_text_search   
    navigate_to_tree_view_for(@project, 'bugfix plan')
    search_through_card_explorer_text_search("##{@r1.number}")
    assert_card_present_in_search_result(@r1)
    assert_searched_cards_disabled_for_drag(@r1)
    search_through_card_explorer_text_search("##{bug_card.number}")
    assert_card_present_in_search_result(bug_card)
    assert_searched_cards_enabled_for_drag(bug_card)
  end

  #bug 2922
  def test_the_default_tab_on_card_explorer_should_be_Filter
    tree = setup_tree(@project, 'bugfix plan', :types => [@type_release, @type_iteration, @type_defect], :relationship_names => ['bugfix plan release', 'bugfix plan iteration'])
    bug_card = create_card!(:name => 'bug100', :card_type => DEFECT)
    add_card_to_tree(tree, @r1)
    open_card_explorer_for(@project, tree)
    @browser.assert_visible("filter-active-tab")
    @browser.assert_visible("search-inactive-tab")
    @browser.assert_not_visible("search-active-tab")
  end


  def test_card_used_in_two_similar_kind_of_trees_should_shown_disabled
    planning1_tree = setup_tree(@project, 'Planning1', :types => [@type_iteration, @type_story], :relationship_names => ['Planning1 iteration'])
    add_card_to_tree(planning1_tree, @i1)
    add_card_to_tree(@tree, @i1)
    @browser.run_once_full_text_search   
    navigate_to_tree_view_for(@project, planning1_tree.name)
    search_through_card_explorer_text_search('iteration')
    assert_searched_cards_disabled_for_drag(@i1)
    navigate_to_tree_view_for(@project, @tree.name)
    search_through_card_explorer_text_search('iteration')
    assert_searched_cards_disabled_for_drag(@i1)
  end

  def test_card_should_available_for_drag_for_tree_which_does_not_have_it_even_its_being_used_by_other_similar_trees
    planning1_tree = setup_tree(@project, 'Planning1', :types => [@type_iteration, @type_story], :relationship_names => ['Planning1 iteration'])
    add_card_to_tree(planning1_tree, @i1)
    @browser.run_once_full_text_search   
    navigate_to_tree_view_for(@project, planning1_tree.name)
    search_through_card_explorer_text_search('iteration')
    assert_searched_cards_disabled_for_drag(@i1)
    navigate_to_tree_view_for(@project, @tree.name)
    search_through_card_explorer_text_search('iteration')
    assert_searched_cards_enabled_for_drag(@i1)
  end

  # bug 3483
  def test_no_results_found_message_is_displayed_when_search_does_not_return_results
    term_that_does_not_exist_in_project = 'penguins!'
    navigate_to_tree_view_for(@project, @tree.name)
    search_through_card_explorer_text_search(term_that_does_not_exist_in_project)
    assert_explorer_results_message("Your search #{term_that_does_not_exist_in_project} did not match any cards for the current tree.")
    assert_explorer_refresh_link_is_present
  end

  # bug 3149
  def test_cards_are_reenabled_in_explorer_immediately_after_being_removed_from_tree
    quick_add_cards_on_tree(@project, @tree, @r1, :card_names => ['iteration1'])
    iteration1 = @project.cards.find_by_name('iteration1')
    open_card_explorer_for(@project, @tree)
    add_new_filter_for_explorer
    set_the_filter_property_and_value(1, :property => TYPE, :value => ITERATION_TYPE)
    assert_card_disabled_in_card_explorer_filter_results(iteration1)
    remove_card_without_its_children_from_tree_for(@project, @tree.name, iteration1, :already_on_tree_view => true)
    assert_card_enabled_in_card_explorer_filter_results(iteration1)
  end
  
  # bug 4098
  def test_quick_search_in_tree_view_does_not_include_tree_root
     navigate_to_tree_view_for(@project, 'Planning2' )
     add_card_to_tree(@tree, @r1)
     search_in_tree_incremental_search_input('a', '2 matches')
   end
end
