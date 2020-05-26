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

# Tags: scenario, bug, navigation, card-list, cards, saved-view
class Scenario26ProjectNavigationTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'Status'
  ITERATION = 'iteration'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_member = users(:project_member)
    @read_only_user = users(:bob)
    @project = create_project(:prefix => 'scenario_26', :users => [users(:admin), @project_member],:read_only_users => [@read_only_user])
    setup_property_definitions :old_type => ['bug', 'story'], STATUS => ['nice', 'good'], ITERATION => [1, 2]
    login_as_admin_user
  end

  def teardown
    @project.deactivate
  end

  def test_can_navigate_to_cards_by_card_number
    create_card!(:name => 'first card')
    card_73 = create_card!(:name => 'second card', :number => 73)
    open_project(@project)
    open_card(@project, card_73.number)
    @browser.assert_location "/projects/#{@project.identifier}/cards/73"
  end

  def test_navigate_to_card_with_bad_number_redirects_to_list
    non_existing_card_number = '8787878'
    open_card(@project, non_existing_card_number)
    @browser.assert_location "/projects/#{@project.identifier}/cards/list"
    assert_error_message("Card #{non_existing_card_number} does not exist.")
  end

  def test_pagination_current_plus_or_minus_three_and_show_up_first_and_last_two
    create_cards(@project, 325)
    navigate_to_card_list_for(@project)
    @browser.assert_element_present 'link=Next'
    @browser.assert_element_not_present 'link=Previous'
    go_to_page(@project,7)
    assert_on_page(@project, 7)
    @browser.assert_element_present 'link=Next'
    @browser.assert_element_present 'link=Previous'
    assert_page_link_present(1)
    assert_page_link_present(2)
    assert_page_link_present(12)
    assert_page_link_present(13)
    assert_page_link_not_present(3)
    assert_page_link_not_present(11)
  end

  def test_first_or_last_within_seven_pages_all_the_page_links_shown
    create_cards(@project, 325)
    navigate_to_card_list_for(@project)
    go_to_page(@project, 6)
    assert_page_link_present(5)
    assert_page_link_present(4)
    assert_page_link_present(3)
    go_to_page(@project, 8)
    assert_page_link_present(9)
    assert_page_link_present(10)
    assert_page_link_present(11)
  end

  def test_property_filters_are_saved_as_part_of_saved_view
    bug = create_card!(:name => '1st bug', :old_type => 'bug')
    story = create_card!(:name => '1st story', :old_type => 'story')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :old_type => 'bug')
    bugs_view = create_card_list_view_for(@project, 'BUGS')

    click_all_tab

    navigate_to_saved_view(bugs_view)
    assert_card_present_in_list(bug)
    assert_card_not_present_in_list(story)
  end

  # bug 694
  def test_should_stay_on_correct_tab_when_viewing_cards
    bug_one = create_card!(:name => 'card1', :old_type => 'bug')
    bug_two = create_card!(:name => 'card1', :old_type => 'bug')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, 'old_type' => 'bug')
    bugs_view = create_card_list_view_for(@project, 'Bugs')

    click_all_tab

    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(bugs_view)

    click_all_tab
    assert_tab_highlighted('All')
    filter_card_list_by(@project, 'old_type' => 'bug')
    assert_tab_highlighted('All')
    click_card_on_list(bug_one)
    assert_tab_highlighted('All')
  end

  # bug 810
  def test_can_create_multiple_saved_views_with_the_same_definition
    card_one = create_card!(:name => 'stuff for test', ITERATION => 1, STATUS => 'nice')
    card_two = create_card!(:name => 'stuff for test', ITERATION => 2, STATUS => 'nice')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, STATUS => 'nice')
    add_column_for(@project, [ITERATION])
    sort_by(ITERATION)

    saved_view = create_card_list_view_for(@project, 'nice with iterations')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(saved_view)

    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, STATUS => 'nice')
    add_column_for(@project, [ITERATION])
    sort_by(ITERATION)

    create_card_list_view_for(@project, 'adding dup')
  end

  # was bug 820 -- we turned off this validation for 2.0 release
  def test_can_switch_between_tabbed_saved_views_and_the_all_tab
    release = 'Release'
    work_status = 'work status'
    setup_property_definitions(release => [1, 1.1, 2], work_status => ['new', 'OPEN'])
    open_one_dot_one_card = create_card!(:name => 'first card', release => 1.1, work_status => 'OPEN')
    open_card = create_card!(:name => 'second card', work_status => 'OPEN')

    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, release => 1.1, work_status => 'OPEN')
    new_release_saved_view = create_card_list_view_for(@project, '1.1 release - Open')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(new_release_saved_view)
    click_overview_tab

    click_tab(new_release_saved_view)
    assert_card_present(open_one_dot_one_card)
    assert_card_not_present(open_card)

    click_all_tab
    assert_card_present(open_one_dot_one_card)
    assert_card_present(open_card)
  end

  # bug 1215
  def test_clicking_clear_all_filters_returns_user_to_all_tab
    card_one = create_card!(:name => 'card one', ITERATION => 1, STATUS => 'nice')
    card_two = create_card!(:name => 'card two', ITERATION => 2, STATUS => 'nice')
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, STATUS => 'nice')
    switch_to_grid_view
    color_by(ITERATION)
    grid_saved_view = create_card_list_view_for(@project, 'grid saved view')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(grid_saved_view)
    click_all_tab
    click_tab(grid_saved_view)
    reset_all_filters_return_to_all_tab
    assert_tab_highlighted('All')
  end

  # bug 2480
  def test_cliking_about_link_does_not_blow_up_mingle
    navigate_to_about_mingle_page
    @browser.assert_text_present('About')
    @browser.assert_text_present('Revision')
  end

  # bug 3338
  def test_non_admin_team_member_should_not_be_able_to_access_advanced_admin_screen
    logout
    login_as_project_member
    @browser.open '/'
    @browser.open "/projects/#{@project.identifier}/admin/advanced"
    @browser.assert_location("/projects/#{@project.identifier}/overview")
    assert_cannot_access_resource_error_message_present
  end

  # bug 3230
  def test_up_link_does_not_change_after_running_transition_on_card
    transition = create_transition(@project, 'make nice', :set_properties => {:status => 'nice'})
    card = create_card!(:name => 'some card', :card_type_name => 'Card')

    create_a_wiki_page_with_text(@project, 'some wiki page', "uniquetext ##{card.number}")
    click_on_card_link_on_wiki_page(card)
    click_transition_link_on_card(transition)
    click_up_link

    assert_text_present("uniquetext")
  end

  # bug 3155
  def test_up_link_on_card_show_takes_user_back_to_correct_page_in_card_list
    total_number_of_pages = 3
    type_bug = setup_card_type(@project, 'bug')
    create_cards(@project, 51, :card_type => type_bug)
    bug_view = create_named_view('bug view', @project)

    open_project(@project)
    click_all_tab
    navigate_to_saved_view(bug_view)

    card_on_page_2 = @project.cards.find_by_number(2)

    click_page_link(2)
    click_card_on_list(card_on_page_2)
    click_up_link

    assert_card_present_in_list(card_on_page_2)
    assert_on_page(@project, 2, tab="All", bug_view.favorite.id)
  end

  # bug 3229
  def test_navigating_via_link_to_card_outside_of_context_and_clicking_up_should_take_user_to_all_tab
    type_story = setup_card_type(@project, 'Story')
    create_tabbed_view('stories', @project, :filters => ['[Type][is][Story]'])
    story = create_card!(:name => 'some story', :card_type => 'Story')
    non_story = create_card!(:name => 'not a story', :card_type => 'Card')

    story.description = "##{non_story.number}"
    story.save!

    open_project(@project)
    click_tab('stories')

    click_card_on_list(story)
    click_on_card_link_on_wiki_page(non_story)

    assert_up_link_text("Up to All")
    click_up_link
    assert_tab_highlighted('All')
  end

  # bug 3607
  def test_navigating_by_clicking_the_up_to_all_link_on_a_card_opened_from_the_tree_view_returns_to_tree_view
    type_story = setup_card_type(@project, 'Story')
    type_task = setup_card_type(@project, 'Task')
    story = create_card!(:name => 'first story', :card_type => 'Story')
    task = create_card!(:name => 'first task', :card_type => 'Task')
    tree = setup_tree(@project, 'testing tree', :types => [type_story, type_task], :relationship_names => ['testing tree - story'])
    add_card_to_tree(tree, story)
    add_card_to_tree(tree, task, story)

    navigate_to_tree_view_for(@project, 'testing tree')
    open_a_card_in_tree_view(@project, story.number)

    assert_previous_link_is_present
    assert_next_link_is_present

    click_up_link
    wait_for_tree_result_load
    assert_current_tree_on_view('testing tree')
  end

  # bug 4542
  def test_card_key_word_page_should_look_like_disabled_for_no_admin
    navigate_to_card_keywords_for(@project)
    assert_keywords_input_is_enabled
    unless using_ie?
      login_as_project_member
      navigate_to_card_keywords_for(@project)
      assert_keywords_input_is_disabled
      login_as_read_only_team_member
      navigate_to_card_keywords_for(@project)
      assert_keywords_input_is_disabled
    end
  end

  #bug 3792
  def test_trying_to_open_url_that_does_not_exist_shows_resource_error_message_and_not_were_sorry_page
    logout
    login_as_project_member
    url_that_does_not_exist_for_project = "/projects/#{@project.identifier}/fooooo"
    @browser.open(url_that_does_not_exist_for_project)
    assert_cannot_access_resource_error_message_present
    @browser.assert_text_not_present("We're sorry")
  end

  private
  def login_as_read_only_team_member
    login_as(@read_only_user.login)
  end
end
