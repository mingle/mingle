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

# Tags: scenario, card-list, cards, tabs, favorites, #2478, #2456, #2478, #2486, #2490, #2499
class Scenario52TabHighlightAndSavedViewsTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  BUG = 'Bug'
  STORY = 'Story'

  PRIORITY = 'Priority'
  STORY_STATUS = 'Story Status'
  BUG_STATUS = 'Bug Status'

  ANY = '(any)'
  NOTSET = '(not set)'
  CURRENT_USER = '(current user)'

  TYPE = 'Type'
  TAG_1 = 'story bug'

  OWNER = 'Owner'

  MAKE_TAB = 'Make tab'
  REMOVE_TAB = 'Remove tab'
  MAKE_TEAM_FAVORITE = 'Make team favorite'
  REMOVE_TEAM_FAVORITE = 'Remove team favorite'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_team_member = users(:existingbob)
    @non_admin_user = users(:longbob)
    @admin = users(:admin)
    @team_member_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_52', :users => [@admin, @team_member_user, @non_admin_user])
    login_as_admin_user

    setup_property_definitions(PRIORITY => ['very high', 'high','medium','low'], BUG_STATUS => ['new', 'open', 'closed'], STORY_STATUS => ['New', 'assigned', 'close'])
    setup_user_definition(OWNER)
    @story_type = setup_card_type(@project, STORY, :properties => [STORY_STATUS, PRIORITY, OWNER])
    @bug_type = setup_card_type(@project, BUG, :properties => [BUG_STATUS, PRIORITY, OWNER])

    @card_1 = create_card!(:name => 'card  set', :card_type  => STORY, PRIORITY  => 'high', OWNER => @admin.id).tag_with(TAG_1)
    @card_2 = create_card!(:name => 'story1', :card_type  => STORY, PRIORITY  => 'high', STORY_STATUS  =>  'New', OWNER => @non_admin_user.id).tag_with(TAG_1)
    @card_3 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'medium', STORY_STATUS =>  'assigned', OWNER => @team_member_user.id)
    @card_4 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY => 'high', BUG_STATUS =>  'new', OWNER => @admin.id).tag_with(TAG_1)
    @card_5 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium', BUG_STATUS =>  'new', OWNER => @non_admin_user.id)
    @card_6 = create_card!(:name => 'bug3', :card_type  => BUG, PRIORITY  => 'low', BUG_STATUS  =>  'closed', OWNER => @team_member_user.id)
    navigate_to_card_list_for(@project)
  end

  # Story 5523
  def test_should_be_able_to_open_saved_view_via_link_on_tab_and_views_management_page
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    story_tab = create_card_list_view_for(@project, 'stories')
    navigate_to_favorites_management_page_for(@project)
    open_saved_view('stories')
    assert_cards_present(@card_1, @card_2, @card_3)
    assert_cards_not_present(@card_4, @card_5, @card_6)

    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(story_tab)
    open_saved_view('stories')
    assert_cards_present(@card_1, @card_2, @card_3)
    assert_cards_not_present(@card_4, @card_5, @card_6)
  end

  # Tabs usage tests
  def test_highlight_tabs_as_close_match_to_filter_selected
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    story_tab = create_card_list_view_for(@project, 'stories')
    set_filter_by_url(@project, "filters[]=[Type][is][#{BUG}]")
    bug_tab = create_card_list_view_for(@project, 'bugs')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(story_tab, bug_tab)
    click_all_tab
    set_the_filter_value_option(0, STORY)
    assert_cards_present(@card_1, @card_2, @card_3)
    assert_cards_not_present(@card_4, @card_5, @card_6)
    assert_tab_highlighted('All')
    set_the_filter_value_option(0, BUG)
    assert_cards_not_present(@card_1, @card_2, @card_3)
    assert_cards_present(@card_4, @card_5, @card_6)

    click_tab('Stories')
    assert_tab_highlighted('stories')
    set_the_filter_value_option(0, BUG)
    assert_cards_not_present(@card_1, @card_2, @card_3)
    assert_cards_present(@card_4, @card_5, @card_6)
  end

  def test_should_not_have_tab_parameter_with_name_of_a_view_that_is_not_a_tab
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    story_tab = create_card_list_view_for(@project, 'stories')
    set_filter_by_url(@project, "filters[]=[Type][is][#{BUG}]")
    bug_tab = create_card_list_view_for(@project, 'bugs')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(bug_tab)
    click_tab('bugs')
    open_saved_view('stories')
    assert_tab_highlighted('All')
    assert_link_not_present("&tab=stories")
    assert_link_present("&tab=All")
  end

  def test_tabs_gets_highlighted_as_filter_changed_to_relevent_between_list_and_grid_view
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    story_tab = create_card_list_view_for(@project, 'stories')
    set_filter_by_url(@project, "filters[]=[Type][is][#{BUG}]")
    bug_tab = create_card_list_view_for(@project, 'bugs')
    filter_type_story_stype_grid = "filters[]=[Type][is][#{STORY}]"
    set_filter_by_url(@project, filter_type_story_stype_grid, 'grid')
    story_with_grid_view = create_card_list_view_for(@project, 'stories on grid')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(story_tab, bug_tab, story_with_grid_view)
    reset_all_filters_return_to_all_tab

    set_the_filter_value_option(0, STORY)
    assert_tab_highlighted('All')
    switch_to_grid_view
    assert_tab_highlighted('All')
    switch_to_list_view
    assert_tab_highlighted('All')

    click_tab('stories on grid')
    set_the_filter_value_option(0, BUG)
    assert_tab_highlighted('stories on grid')
    switch_to_list_view
    assert_tab_highlighted('stories on grid')
    switch_to_grid_view
    assert_tab_highlighted('stories on grid')
  end

  def test_should_allow_creation_of_tabs_with_same_filter_condition_as_post_2_0_there_is_no_reason_to_disallow_this
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    view_name = 'stories'
    story_tab = create_card_list_view_for(@project, view_name)
    set_filter_by_url(@project, "filters[]=[Type][is][#{BUG}]")
    bug_tab = create_card_list_view_for(@project, 'bugs')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(story_tab, bug_tab)
    click_tab(view_name)
    create_card_list_view_for(@project, 'stories second')
    navigate_to_favorites_management_page_for(@project)
    assert_card_favorites_present_on_management_page(@project, 'stories second')
  end

  def test_mywork_tab_highlights_and_retaines_its_context_while_card_open
    filter_my_work = "filters[]=[#{OWNER}][is][(current user)]"
    set_filter_by_url(@project, filter_my_work)
    tab_my_work = create_card_list_view_for(@project, 'my work')
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    story_tab = create_card_list_view_for(@project, 'stories')
    set_filter_by_url(@project, "filters[]=[Type][is][#{BUG}]")
    bug_tab = create_card_list_view_for(@project, 'bugs')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(bug_tab, tab_my_work, story_tab)
    click_tab('my work')
    assert_cards_present(@card_1, @card_4)
    open_card(@project, @card_4.number)
    assert_tab_highlighted('my work')
    click_next_link
    assert_tab_highlighted('my work')

    click_tab('bugs')
    open_card(@project, @card_4.number)
    assert_tab_highlighted('bugs')
    click_next_link
    assert_tab_highlighted('bugs')
  end

  def test_tabs_with_is_not_operator
    set_filter_by_url(@project, "filters[]=[Type][is not][#{STORY}]")
    assert_cards_present(@card_4, @card_5, @card_6)
    tab_other_than_story = create_card_list_view_for(@project, 'other than story')
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    assert_cards_present(@card_1, @card_2, @card_3)
    tab_story = create_card_list_view_for(@project, 'stories')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_other_than_story, tab_story)

    click_all_tab
    select_is_not(0)
    set_the_filter_value_option(0, STORY)
    assert_tab_highlighted('All')

    click_tab('other than story')
    set_the_filter_value_option(0, 'Card')
    click_tab('other than story')
  end

  #bug 2478
  def test_just_lane_difference_in_two_tabs_will_allow_viewing_both_tabs
    filter_type_story_stype_grid_with_3lanes = "filters[]=[Type][is][#{STORY}]&group_by=#{PRIORITY}&lanes=+,High,Medium,Low"
    filter_type_story_stype_grid_with_2lanes = "filters[]=[Type][is][#{STORY}]&group_by=#{PRIORITY}&lanes=+,High,Low,"
    set_filter_by_url(@project, filter_type_story_stype_grid_with_3lanes, 'grid')
    tab_with_3lanes = create_card_list_view_for(@project, 'tab_with_3lanes')
    set_filter_by_url(@project, filter_type_story_stype_grid_with_2lanes, 'grid')
    tab_with_2lanes = create_card_list_view_for(@project, 'tab_with_2lanes')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_with_3lanes, tab_with_2lanes)
    click_tab('tab_with_3lanes')
    assert_tab_highlighted('tab_with_3lanes')
    click_tab('tab_with_2lanes')
    assert_tab_highlighted('tab_with_2lanes')
  end

  #Bug 2456
  def test_updating_the_tab_content_wont_stop_going_back_to_all_tab
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    tab_getting_update = create_card_list_view_for(@project, 'high priority cards')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_getting_update)
    click_all_tab
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'high')
    create_card_list_view_for(@project, 'high priority cards')
    assert_tab_highlighted('high priority cards')
    click_all_tab
    assert_tab_highlighted('All')
  end

  #Bug 2479
  def test_tab_highlight_for_created_by_and_modified_by_lanes_gets_precedence_on_close_match
    filter_with_columns_created_by_modified_by = "&columns=Created+by,Modified+by"
    filter_with_columns_status_priority_and_owner = "&columns=#{PRIORITY},#{OWNER}"
    set_filter_by_url(@project, filter_with_columns_created_by_modified_by)
    tab_with_columns_created_by_modified_by = create_card_list_view_for(@project, 'tab_with_columns_created_by_modified_by')
    set_filter_by_url(@project, filter_with_columns_status_priority_and_owner)
    tab_with_columns_priority_owner = create_card_list_view_for(@project, 'tab_with_columns_priority_and_owner')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_with_columns_priority_owner, tab_with_columns_created_by_modified_by)
    click_all_tab
    add_column_for(@project, ['Created by'])
    assert_tab_highlighted('All')
    assert_reset_to_tab_default_link_present

    click_tab('tab_with_columns_priority_and_owner')
    remove_column_for(@project, [PRIORITY])
    assert_tab_highlighted('tab_with_columns_priority_and_owner')
    assert_reset_to_tab_default_link_present
  end

  #2486
  def test_tab_highlight_the_colsest_match_irrespctive_of_grid_or_list_view
    filter_type_story_priority_high_list = "filters[]=[Type][is][#{STORY}]&filters[]=[#{PRIORITY}][is][high]"
    filter_type_story_priority_high_medium_grid = "filters[]=[Type][is][#{STORY}]&filters[]=[#{PRIORITY}][is][high]&filters[]=[#{PRIORITY}][is][medium]"
    set_filter_by_url(@project, filter_type_story_priority_high_list)
    tab_type_story_priority_high_list = create_card_list_view_for(@project, 'story=high')
    set_filter_by_url(@project, filter_type_story_priority_high_medium_grid, 'grid')
    tab_type_story_priority_high_medium_grid = create_card_list_view_for(@project, 'story = high & medium')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_type_story_priority_high_list, tab_type_story_priority_high_medium_grid)
    click_all_tab
    switch_to_grid_view
    set_the_filter_value_option(0, STORY)
    assert_tab_highlighted('All')
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'high')
    assert_tab_highlighted('All')
    add_new_filter
    set_the_filter_property_and_value(2, :property => PRIORITY, :value => 'medium')
    assert_tab_highlighted('All')

    #scenario 2
    click_tab('story=high')
    switch_to_grid_view
    assert_tab_highlighted('story=high')
  end

  #Bug 2490 - this is no longer a bug, as we turned off the validation to detect identical views
  #in release 2.0, because containment is no longer used to determine tabs.
  def test_can_create_a_view_with_the_same_definition_as_the_all_tab
    set_filter_by_url(@project, "filters[]", 'grid')
    all_tab_grid_view = create_card_list_view_for(@project, 'All tab with grid view')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(all_tab_grid_view)
    click_tab('All tab with grid view')
    switch_to_list_view
    all_with_style_list = create_card_list_view_for(@project, 'All With style List')
    navigate_to_favorites_management_page_for(@project)
    assert_card_favorites_present_on_management_page(@project, all_with_style_list)
  end

  def test_project_admin_can_manage_favorites_and_tabs_on_project_admin_page
    wiki1 = create_a_wiki_page_with_text(@project, 'wiki page1', 'wiki page 1')
    wiki2 = create_a_wiki_page_with_text(@project, 'wiki page2', 'wiki page 2')
    make_wiki_as_tab_for(@project, wiki2)
    open_wiki_page(@project, wiki1.name)
    make_wiki_as_favorite_for(@project, wiki1)
    navigate_to_favorites_management_page_for(@project)
    assert_tabs_present_on_management_page(wiki2)
    assert_tabs_not_present_on_management_page(wiki1)
    assert_card_favorites_present_on_management_page(@project, wiki1)
    assert_favorites_not_present_on_management_page(@project, wiki2)
  end

  def test_project_manager_should_be_allowed_to_tabify_a_mingle_admin_created_wiki_page
    wiki1 = create_a_wiki_page_with_text(@project, 'wiki page1', 'Tabified by mingle admin')
    make_wiki_as_tab_for(@project, wiki1)

    as_user(@team_member_user.login) do
      proj_admin = User.current
      assert_equal false, proj_admin.admin?
      @project.add_member(proj_admin, :project_admin)
      open_wiki_page(@project, wiki1.name)
      assert_favorite_link_on_wiki_action_bar_as(MAKE_TEAM_FAVORITE)
      make_wiki_as_favorite_for(@project, wiki1)
      assert_tab_not_present(wiki1.name)
      assert_manage_favorites_and_tabs_link_present
    end
  end

  def test_project_member_cannot_modify_tabs_set_by_admin
    wiki1 = create_a_wiki_page_with_text(@project, 'wiki page1', 'wiki page 1')
    wiki2 = create_a_wiki_page_with_text(@project, 'wiki page2', 'wiki page 2')
    make_wiki_as_tab_for(@project, wiki2)
    open_wiki_page(@project, wiki1.name)
    make_wiki_as_favorite_for(@project, wiki1)

    as_user(@non_admin_user.login, 'longtest') do
      navigate_to_favorites_management_page_for(@project)
      assert_favorites_not_editable(wiki1)
      assert_tabs_not_editable(wiki2)
    end
  end

  # Favorites realted usage tests
  def test_non_tabbed_favorite_can_be_updated_by_a_team_member
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    story_tab = create_card_list_view_for(@project, 'stories')
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{PRIORITY}][is][medium]")
    bug_tab = create_card_list_view_for(@project, 'stories with priority')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(story_tab)

    as_user(@team_member_user.login) do
      click_tab('stories')
      add_new_filter
      set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'high')
      update_favorites_for(1)
      open_favorites_for(@project, 'stories with priority')
      assert_cards_present(@card_1, @card_2)
    end
  end

  def test_should_be_able_to_create_saved_view_with_type_set_to_any
    select_is_not(0)
    select_is(0)
    saved_view_all = create_card_list_view_for(@project, 'All-all')
    navigate_to_favorites_management_page_for(@project)
    assert_card_favorites_present_on_management_page(@project, 'All-all')
  end

  def test_wiki_page_can_be_set_as_favorites_and_set_as_tab
    dev_notes = create_a_wiki_page_with_text(@project, 'dev notes', "this is a note for story 1 blah blah")
    assert_favorite_link_on_wiki_action_bar_as(MAKE_TEAM_FAVORITE)
    make_wiki_as_favorite_for(@project, dev_notes)
    assert_favorite_link_on_wiki_action_bar_as(REMOVE_TEAM_FAVORITE)
    assert_wiki_favorites_present(@project, dev_notes.name)
    make_wiki_as_tab_for(@project, dev_notes)
    assert_tab_link_on_wiki_action_bar_as(REMOVE_TAB)
    assert_favorite_link_on_wiki_action_bar_as(MAKE_TEAM_FAVORITE)
    assert_tab_present(dev_notes.name)
  end

  def test_project_admin_can_remove_wiki_pages_as_tabs_or_favorites
    wiki1 = create_a_wiki_page_with_text(@project, 'wiki page1', 'wiki page 1')
    wiki2 = create_a_wiki_page_with_text(@project, 'wiki page2', 'wiki page 2')
    make_wiki_as_tab_for(@project, wiki2)

    open_wiki_page(@project, wiki1.name)
    make_wiki_as_favorite_for(@project, wiki1)
    assert_wiki_favorites_present(@project, wiki1.name)
    assert_tab_present(wiki2.name)

    click_remove_from_favorites_through_wiki_page(@project, wiki1)
    assert_favorite_link_on_wiki_action_bar_as(MAKE_TEAM_FAVORITE)
    assert_wiki_favorites_not_present(@project, wiki1.name)

    open_wiki_page(@project, wiki2.name)
    assert_tab_present(wiki2.name)
    click_remove_from_tabs_through_wiki_page(@project, wiki2)
    assert_tab_not_present(wiki2.name)
  end

  def test_project_member_can_modify_favorites_set_by_admin_or_new_favorites_but_not_tabs
    wiki1 = create_a_wiki_page_with_text(@project, 'wiki page1', 'wiki page 1')
    wiki2 = create_a_wiki_page_with_text(@project, 'wiki page2', 'wiki page 2')
    make_wiki_as_tab_for(@project, wiki2)
    open_wiki_page(@project, wiki1.name)
    make_wiki_as_favorite_for(@project, wiki1)

    as_user(@non_admin_user.login, 'longtest') do
      open_wiki_page(@project, wiki1.name)
      assert_favorite_link_on_wiki_action_bar_as(REMOVE_TEAM_FAVORITE)
      assert_tab_link_not_present_on_wiki_action_bar
      click_remove_from_favorites_through_wiki_page(@project, wiki1)
      assert_favorite_link_on_wiki_action_bar_as(MAKE_TEAM_FAVORITE)

      click_tab(wiki2.name)
      assert_tab_link_not_present_on_wiki_action_bar
      assert_favorites_link_not_present_on_wiki_action_bar

      wiki3 = create_a_wiki_page_with_text(@project, 'wiki page 3', 'wiki page three')
      assert_favorite_link_on_wiki_action_bar_as(MAKE_TEAM_FAVORITE)
      make_wiki_as_favorite_for(@project, wiki3)
      assert_wiki_favorites_present(@project, wiki3.name)
    end
  end

  def test_there_can_be_a_wiki_favorite_and_card_favorites_with_same_name
    wiki1 = create_a_wiki_page_with_text(@project, 'foo', 'Foo')
    make_wiki_as_favorite_for(@project, wiki1)
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    foo = create_card_list_view_for(@project, 'foo')
    assert_wiki_favorites_present(@project, wiki1.name)
    assert_card_favorites_link_present(foo.name)
  end

  # story 5986
  def test_tab_reset_link_should_be_present_upon_changes_on_list_view
    tab_name = 'testing'
    create_tabbed_view(tab_name, @project, :filters => ['[Type][is][Story]'])
    tree = setup_tree(@project, 'Simple Tree', :types => [@story_type, @bug_type], :relationship_names => ["which story?"])

    reload_current_page

    click_tab(tab_name)
    assert_reset_to_tab_default_link_not_present
    add_column_for(@project,%w(Type))
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    remove_column_for(@project, ['Type'])
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    sort_by('#')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    set_the_filter_value_option(0, BUG)
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    select_tree('Simple Tree')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    switch_to_grid_view
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    select_tree('None')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

  end

  def test_tab_reset_link_should_be_present_upon_changes_on_grid_view
    tab_name = 'testing'
    setup_numeric_property_definition('Size',[2,4])
    create_tabbed_view(tab_name, @project, :filters => ['[Type][is][Bug]'], :style => 'grid')
    tree = setup_tree(@project, 'Simple Tree', :types => [@story_type, @bug_type], :relationship_names => ["which story?"])

    reload_current_page

    click_tab(tab_name)
    assert_reset_to_tab_default_link_not_present
    group_columns_by('Type')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    add_lanes(@project, TYPE, ['Bug'], :type => true)

    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    grid_sort_by('Number')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    color_by(PRIORITY)
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    change_lane_heading('Sum', 'Size')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present
  end

  def test_tab_reset_link_should_be_present_upon_changes_on_hierarchy_view
    tab_name = 'testing'
    setup_numeric_property_definition('Size',[2,4])
    tree = setup_tree(@project, 'Simple Tree', :types => [@story_type, @bug_type], :relationship_names => ["which story?"])
    add_card_to_tree(tree, @card_2)
    add_card_to_tree(tree, @card_4, @card_2)
    create_tabbed_view(tab_name, @project, :tree_name => 'Simple Tree', :style => 'hierarchy')

    reload_current_page

    click_tab(tab_name)
    assert_reset_to_tab_default_link_not_present
    @browser.assert_element_present('twisty_for_card_2')
    click_twisty_for(@card_2)
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    click_exclude_card_type_checkbox(STORY)
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    set_tree_filter_for(@story_type, 0, :property => PRIORITY, :value => 'high')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present
  end

  def test_tab_reset_link_should_be_present_upon_changes_on_tree_view
    tab_name = 'testing'
    setup_numeric_property_definition('Size',[2,4])
    tree = setup_tree(@project, 'Simple Tree', :types => [@story_type, @bug_type], :relationship_names => ["which story?"])
    add_card_to_tree(tree, @card_2)
    add_card_to_tree(tree, @card_4, @card_2)
    create_tabbed_view(tab_name, @project, :tree_name => 'Simple Tree', :style => 'tree')

    reload_current_page

    click_tab(tab_name)
    assert_reset_to_tab_default_link_not_present
    expand_collapse_nodes_in_tree_view(@card_2)
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    click_exclude_card_type_checkbox(STORY)
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present

    set_tree_filter_for(@story_type, 0, :property => PRIORITY, :value => 'high')
    assert_reset_to_tab_default_link_present
    save_tab(tab_name)
    assert_reset_to_tab_default_link_not_present
  end

  #bug 8694
  def test_should_remove_highlighted_favorite_when_expand_or_collapse_nodes_in_tree
    tab_name = 'testing'
    setup_numeric_property_definition('Size',[2,4])
    tree = setup_tree(@project, 'Simple Tree', :types => [@story_type, @bug_type], :relationship_names => ["which story?"])
    add_card_to_tree(tree, @card_2)
    add_card_to_tree(tree, @card_4, @card_2)
    navigate_to_tree_view_for(@project, 'Simple Tree')
    expand_collapse_nodes_in_tree_view(@card_2)
    tree_view = create_card_list_view_for(@project, 'saved tree')
    assert_fav_view_highlighted("tree", tree_view)
    expand_collapse_nodes_in_tree_view(@card_2)
    assert_fav_view_not_highlighted("tree", tree_view)

    tree_view = create_card_list_view_for(@project, 'saved tree expanded')
    assert_fav_view_highlighted("tree", tree_view)
    expand_collapse_nodes_in_tree_view(@card_2)
    assert_fav_view_not_highlighted("tree", tree_view)
  end

  #bug 2877
  def test_update_favorites_link_should_not_be_present_for_wiki_favorites
    wiki1 = create_a_wiki_page_with_text(@project, 'Wiki page foo', 'Foo')
    make_wiki_as_favorite_for(@project, wiki1)
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    story_tab = create_card_list_view_for(@project, 'stories')
    click_all_tab
    set_filter_by_url(@project, "filters[]=[Type][is][#{BUG}]")
    assert_save_icon_for_favorites_present(story_tab.name, 0)
    assert_update_icon_not_present_for_wiki(wiki1.name, 1)
  end

  #bug 2717
  def test_filter_with_set_value_ANY_should_not_be_part_of_favorites_when_change_from_is_not_to_is_operator_in_filter_list
    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_option(1, PRIORITY)
    select_is_not(1)
    select_is(1)
    saved_view_all = create_card_list_view_for(@project, 'All-all')
    open_saved_view(saved_view_all.name)
    assert_filter_not_present_for(1)
  end

  def test_table_view_query_for_favorites_show_up_valid_data
    set_filter_by_url(@project, "filters[]=[Type][is not][#{STORY}]")
    assert_cards_present(@card_4, @card_5, @card_6)
    add_column_for(@project, [BUG_STATUS, PRIORITY])
    tab_other_than_story = create_card_list_view_for(@project, 'other than story')
    edit_overview_page
    favorite_view_table = add_table_view_query_and_save(tab_other_than_story.name)
    assert_table_column_headers_and_order(favorite_view_table, 'Number', 'Name', BUG_STATUS, PRIORITY)
    assert_table_row_data_for(favorite_view_table, :row_number => 1, :cell_values => ['6', 'bug3', 'closed', 'low'])
    assert_table_row_data_for(favorite_view_table, :row_number => 2, :cell_values => ['5', 'bug2', 'new', 'medium'])
    assert_table_row_data_for(favorite_view_table, :row_number => 3, :cell_values => ['4', 'bug1', 'new', 'high'])
  end

  #bug 3007
  def test_table_view_query_throws_valid_error_message_for_grid_view_favorites
    wiki1 = create_a_wiki_page_with_text(@project, 'wiki1', 'Hello world ...')
    make_wiki_as_favorite_for(@project, wiki1)
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]", 'grid')
    assert_cards_present(@card_1, @card_2, @card_3)
    stories_in_grid_view = create_card_list_view_for(@project, 'stories in grid')
    edit_overview_page
    insert_table_view_macro(stories_in_grid_view.name)
    assert_mql_error_messages("Error in table macro: Table view is only available to list views. #{stories_in_grid_view.name} is not a list view.")
    click_cancel_on_wysiwyg_editor
    insert_table_view_macro(wiki1.name)
    assert_mql_error_messages("Error in table macro: No such view: #{wiki1.name}")
  end

  # bug 2885
  def test_when_wiki_set_as_favorite_it_will_highlight_overview_tab
    wiki1 = create_a_wiki_page_with_text(@project, 'wiki1', 'Hello world ...')
    make_wiki_as_favorite_for(@project, wiki1)
    assert_tab_highlighted('Overview')
  end

  # bug 8707
  def test_when_wiki_set_as_favorite_it_will_highlight_the_wiki_fav
    wiki = create_a_wiki_page_with_text(@project, 'wiki1', 'Hello world ...')
    make_wiki_as_favorite_for(@project, wiki)
    assert_team_fav_wiki_highlighted(@project.pages.find_by_name('wiki1'))
  end

   # bug 3713
   def test_an_updated_tab_keeps_star_sign_of_modified_content_when_user_moves_to_pure_default_All_tab
     navigate_to_card_list_for(@project)
     new_tab_name = 'testingtab'
     saved_view = create_card_list_view_for(@project, new_tab_name)
     navigate_to_favorites_management_page_for(@project)
     toggle_tab_for_saved_view(saved_view)
     click_tab(new_tab_name)
     set_the_filter_value_option(0, 'Bug')
     edit_overview_page
     click_all_tab
     assert_updated_tab_has_star(new_tab_name)
   end

   # story #5982 fav highlight story
   def test_adding_removing_sorting_columns_on_list_view_would_lose_favorite_highlight
     set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&columns=Modified+by")
     list_view = create_card_list_view_for(@project, 'stories')
     open_saved_view('stories')
     assert_fav_view_highlighted("list", list_view)
     add_column_for(@project, ['Created by'])
     assert_fav_view_not_highlighted("list", list_view)

     open_saved_view('stories')
     remove_column_for(@project, ['Modified by'])
     assert_fav_view_not_highlighted("list", list_view)

     open_saved_view('stories')
     sort_by('#')
     assert_fav_view_not_highlighted("list", list_view)
   end

   def test_swithing_to_different_view_would_lose_favorite_highlight
     set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&columns=Modified+by")
     list_view = create_card_list_view_for(@project, 'stories')
     open_saved_view('stories')
     assert_fav_view_highlighted("list", list_view)
     switch_to_grid_view
     assert_fav_view_not_highlighted("list", list_view)
   end

   def test_changing_group_by_sort_by_color_by_lane_headings_on_grid_view_would_lose_favorite_highlight
     size_property = setup_numeric_property_definition('Size',[2,4])
     size_property.update_attributes(:card_types => [@story_type])

     filter_to_get_a_grid_view = "filters[]=[Type][is][#{STORY}]&sort_by=Number&color_by=#{STORY_STATUS}&group_by=#{PRIORITY}&lanes=+,High,Medium,Low"
     set_filter_by_url(@project, filter_to_get_a_grid_view, 'grid')
     grid_view = create_card_list_view_for(@project, 'stories')
     open_saved_view('stories')
     assert_fav_view_highlighted("grid", grid_view)
     group_columns_by('Type')
     assert_fav_view_not_highlighted("grid", grid_view)

     open_saved_view('stories')
     group_columns_by('Type')
     assert_fav_view_not_highlighted("grid", grid_view)

     open_saved_view('stories')
     color_by(PRIORITY)
     assert_fav_view_not_highlighted("grid", grid_view)

     open_saved_view('stories')
     grid_sort_by(PRIORITY)
     assert_fav_view_not_highlighted("grid", grid_view)

     open_saved_view('stories')
     change_lane_heading('Sum', 'Size')
     assert_fav_view_not_highlighted("grid", grid_view)
   end

   def test_adding_removing_lanes_on_grid_view_would_lose_favorite_highlight
     filter_to_get_a_grid_view = "filters[]=[Type][is][#{STORY}]&sort_by=Number&color_by=#{STORY_STATUS}&group_by=#{PRIORITY}&lanes=+,High"
     set_filter_by_url(@project, filter_to_get_a_grid_view, 'grid')
     grid_view = create_card_list_view_for(@project, 'stories')
     open_saved_view('stories')
     assert_fav_view_highlighted("grid", grid_view)
     add_lanes(@project, PRIORITY, ['low'])
     assert_fav_view_not_highlighted("grid", grid_view)
   end

   def test_changing_filters_would_lose_favorite_highlight
     set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&columns=Modified+by")
     view_with_normal_filter = create_card_list_view_for(@project, 'view_1')
     open_saved_view('view_1')
     assert_fav_view_highlighted("list", view_with_normal_filter)
     set_the_filter_value_option(0, BUG)
     assert_fav_view_not_highlighted("list", view_with_normal_filter)

     set_filter_by_url(@project, "filters[mql]=[Type][is][#{STORY}]&columns=Modified+by")
     view_with_mql_filter = create_card_list_view_for(@project, 'view_2')
     open_saved_view('view_2')
     assert_fav_view_highlighted("list", view_with_mql_filter)
     set_mql_filter_for("Type = #{BUG}")
     assert_fav_view_not_highlighted("list", view_with_mql_filter)
   end

   def test_changing_tree_would_lose_favorite_highlight
     tree = setup_tree(@project, 'Simple Tree', :types => [@story_type, @bug_type], :relationship_names => ["which story?"])
     set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&columns=Modified+by")
     view_without_tree = create_card_list_view_for(@project, 'no tree')
     open_saved_view('no tree')
     assert_fav_view_highlighted("list", view_without_tree)
     select_tree('Simple Tree')
     assert_fav_view_not_highlighted("list", view_without_tree)
   end

   def test_changing_tree_filter_would_lose_favorite_highlight
     create_and_configure_new_card_tree(@project, :name => 'Simple Tree', :types => [STORY, BUG])
     set_filter_by_url(@project, "&tree_name=Simple+Tree")
     view_with_tree = create_card_list_view_for(@project, 'with tree')
     open_saved_view('with tree')
     assert_fav_view_highlighted("list", view_with_tree)
     click_exclude_card_type_checkbox(@bug_type)
     assert_fav_view_not_highlighted("list", view_with_tree)
   end

   # bug #8708
   def test_favorite_would_be_highlighted_after_it_is_created
     set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&columns=Modified+by")
     list_view = create_card_list_view_for(@project, 'stories')
     assert_fav_view_highlighted("list", list_view)
     add_column_for(@project, ['Created by'])
     assert_fav_view_not_highlighted("list", list_view)
   end

   # bug #8692
   def test_favorite_do_not_lose_highlight_when_go_to_page_2
     create_cards(@project, 30)
     saved_view = create_card_list_view_for(@project,'view with more than 1 page')
     @browser.click_and_wait('link=Next')
     assert_fav_view_highlighted("list", saved_view)
   end

   # bug #8683
   def test_favorite_should_not_be_highlighted_when_sort_by_is_changed_by_turing_rank_on
     set_filter_by_url(@project, "filters[]=[Type][is][Story]&grid_sort_by=Number", 'grid')
     saved_view = create_card_list_view_for(@project, 'sortByNumber')
     assert_fav_view_highlighted("grid", saved_view)
     turn_on_rank_mode
     assert_fav_view_not_highlighted("grid", saved_view)
   end

   #8690
   def test_bulk_transition_after_bulk_editing_should_make_fav_highlight_go_away
     card_type = @project.card_types.find_by_name('Card')
     setup_numeric_property_definition('size',[1]).update_attributes(:card_types => [card_type])
     transition = create_transition(@project,'transition', :card_type => card_type,:set_properties => {:size => '1'})
     cards_used_in_this_test = create_cards(@project, 2, :card_type => card_type )

     navigate_to_card_list_for(@project)
     saved_view = create_card_list_view_for(@project, 'test highlight')
     select_cards(cards_used_in_this_test)
     click_bulk_tag_button
     bulk_tag_with('any tag')
     execute_bulk_transition_action(transition)
     assert_fav_view_highlighted("list", saved_view)
   end
end

