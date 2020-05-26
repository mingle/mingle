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

# Tags: scenario, card-list, cards, tabs, favorites, #2478, #2456, #2486, #2490, #2499, #6142, card-selector
class Scenario89SavedViewsTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  BUG = 'Bug'
  STORY = 'Story'

  PRIORITY = 'Priority'
  STORY_STATUS = 'Story Status'
  BUG_STATUS = 'Bug Status'
  HIGH = 'high'

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
    @team_member_user = users(:project_member)
    @project = create_project(:prefix => 'scenario_89', :users => [@admin, @team_member_user, @non_admin_user])
    login_as_admin_user

    setup_property_definitions(PRIORITY => ['very high', HIGH,'medium','low'], BUG_STATUS => ['new', 'open', 'closed'], STORY_STATUS => ['New', 'assigned', 'close'])
    setup_user_definition(OWNER)
    @type_story = setup_card_type(@project, STORY, :properties => [STORY_STATUS, PRIORITY, OWNER])
    @type_bug = setup_card_type(@project, BUG, :properties => [BUG_STATUS, PRIORITY, OWNER])

    @card_1 = create_card!(:name => 'card  set', :card_type  => STORY, PRIORITY  => HIGH, OWNER => @admin.id).tag_with(TAG_1)
    @story_1 = create_card!(:name => 'story1', :card_type  => STORY, PRIORITY  => HIGH, STORY_STATUS  =>  'New', OWNER => @non_admin_user.id).tag_with(TAG_1)
    @story_2 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'medium', STORY_STATUS =>  'assigned', OWNER => @team_member_user.id)
    @bug_1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY => HIGH, BUG_STATUS =>  'new', OWNER => @admin.id).tag_with(TAG_1)
    @bug_2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium', BUG_STATUS =>  'new', OWNER => @non_admin_user.id)
    @bug_3 = create_card!(:name => 'bug3', :card_type  => BUG, PRIORITY  => 'low', BUG_STATUS  =>  'closed', OWNER => @team_member_user.id)
    navigate_to_card_list_for(@project)
  end

  def test_removing_plv_removes_saved_views_and_tabs_using_the_url
    create_favorites_and_a_tab_for_a_tree_using_card_plv
    navigate_to_project_variable_management_page_for(@project)
    delete_project_variable(@project, @plv.name)
    assert_info_box_light_message("The following 2 team favorites will be deleted: #{@saved_view2.name} and #{@saved_view1.name}")
    click_on_continue_to_delete_link
    navigate_to_favorites_management_page_for(@project)
    assert_favorites_not_present_on_management_page(@project, @saved_view1, @saved_view2)
    assert_tabs_not_present_on_management_page(@saved_view1, @saved_view2)
  end

  # bug 2883
  def test_team_member_that_is_not_admin_does_not_see_manage_favorites_and_tabs_link
    logout
    login_as_project_member
    navigate_to_card_list_for(@project)
    expand_favorites_menu
    assert_manage_favorites_and_tabs_link_not_present
  end

  # bug 3652
  def test_saved_views_with_same_name_should_be_project_specific
    saved_view_name = 'foo'
    decoy_project = create_project(:prefix => 'decoy', :users => [@admin, @team_member_user, @non_admin_user])
    decoy_project.activate
    setup_property_definitions(PRIORITY => [HIGH])
    setup_card_type(decoy_project, BUG, :properties => [PRIORITY])
    decoy_card = create_card!(:name => 'decoy card', PRIORITY => HIGH)
    navigate_to_card_list_for(decoy_project)
    add_column_for(decoy_project, [PRIORITY])
    create_card_list_view_for(decoy_project, saved_view_name)
    edit_overview_page
    decoy_table = add_table_view_query_and_save(saved_view_name)

    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => STORY, OWNER => @non_admin_user.name)
    create_card_list_view_for(@project, saved_view_name)
    edit_overview_page
    project_table = add_table_view_query_and_save(saved_view_name)

    navigate_to_project_overview_page(decoy_project)
    assert_table_column_headers_and_order(decoy_table, 'Number', 'Name', PRIORITY)
    assert_table_row_data_for(decoy_table, :row_number => 1, :cell_values => [decoy_card.number, decoy_card.name, HIGH])

    navigate_to_project_overview_page(@project)
    assert_table_column_headers_and_order(project_table, 'Number', 'Name')
    assert_table_row_data_for(project_table, :row_number => 1, :cell_values => [@story_1.number, @story_1.name])
  end

  #bug 4668
  def test_renamed_property_should_be_kept_which_is_used_as_a_column_in_list_or_hierachy_view
    filter_card_list_by(@project, :type => STORY)
    add_column_for(@project, [PRIORITY])
    story_wall = create_card_list_view_for(@project, 'story_wall')
    open_property_for_edit(@project, PRIORITY)
    type_property_name('new_priority')
    click_save_property
    assert_property_updated_success_message_present
    click_all_tab
    navigate_to_saved_view(story_wall.name)
    assert_column_present_for('new_priority')
  end

  # bug 3805.
  def test_deleting_project_with_favorites_should_not_stop_future_project_favorites_from_being_created
    other_project = create_project(:prefix => 'other', :users => [@admin, @team_member_user, @non_admin_user])
    other_wiki_page = create_wiki_page_as_favorite(other_project, 'name', 'content')
    assert_wiki_favorites_present(other_project, other_wiki_page.name)
    delete_project_permanently(other_project)

    wiki_page = create_wiki_page_as_favorite(@project, 'I know my first name is', 'Steven')
    assert_wiki_favorites_present(@project, wiki_page.name)
  end

  # bug 3511
  def test_can_create_table_view_from_a_list_view_that_filters_with_a_relationship_property_plv
    story_property_name = 'some tree - story'

    tree = setup_tree(@project, 'some tree', :types => [@type_story, @type_bug], :relationship_names => [story_property_name])
    add_card_to_tree(tree, [@story_1], :root)
    add_card_to_tree(tree, [@bug_1, @bug_2], @story_1)

    plv = setup_project_variable(@project, :name => 'main story', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_story, :value => @story_1, :properties => [story_property_name])

    click_all_tab
    filter_card_list_by(@project, :type => @type_bug.name, story_property_name => plv_display_name(plv))
    saved_view = create_card_list_view_for(@project, 'bugs for main story')

    edit_overview_page
    view_table = add_table_view_query_and_save(saved_view.name)
    assert_table_row_data_for(view_table, :row_number => 1, :cell_values => [@bug_2.number, @bug_2.name])
    assert_table_row_data_for(view_table, :row_number => 2, :cell_values => [@bug_1.number, @bug_1.name])
  end

  #bug 4148
  def test_disassociating_property_from_tree_deletes_the_project_level_variable
    create_favorites_and_a_tab_for_a_tree_using_card_plv
    open_project_variable_for_edit(@project, @plv.name)
    uncheck_properties_that_will_use_variable(@project, @story_property_name)
    click_save_project_variable
    assert_info_box_light_message("The following 2 team favorites will be deleted: #{@saved_view2.name} and #{@saved_view1.name}")
  end

  # Bug 4539
  def test_removing_team_member_from_project_will_update_favorite_to_not_set_and_populate_the_list_view
    card_with_no_owner_set = create_card!(:name => 'card with no owner', :card_type => BUG)
    filter_card_list_by(@project, OWNER => @non_admin_user.name)
    favorite1 = create_card_list_view_for(@project, "cards for non admin user")
    remove_from_team_for(@project, @non_admin_user, :update_permanently => true)
    navigate_to_card_list_for(@project)
    open_saved_view(favorite1.name)
    assert_card_present_in_list(card_with_no_owner_set)
    assert_card_present_in_list(@story_1)
    assert_card_present_in_list(@bug_2)
  end

  # bug 6142
  def test_should_rename_tree_usage_in_a_saved_view_with_a_mql_filter_when_a_tree_is_renamed
    mql_filtered_view_name = 'card in story bugs tree'
    original_tree_name = "story bugs 3"
    new_tree_name = "story bugs 3"

    tree = setup_tree(@project, original_tree_name, :types => [@type_story, @type_bug], :relationship_names => ['buggy story'])
    set_mql_filter_for("FROM TREE '#{original_tree_name}'")
    create_card_list_view_for(@project, mql_filtered_view_name)
    edit_card_tree_configuration(@project, original_tree_name, :new_tree_name => new_tree_name)

    click_all_tab
    open_saved_view(mql_filtered_view_name)
    assert_mql_filter("FROM TREE '#{new_tree_name}'")
  end

  private

  def create_favorites_and_a_tab_for_a_tree_using_card_plv
    @story_property_name = 'some tree - story'
    @tree = setup_tree(@project, 'some tree', :types => [@type_story, @type_bug], :relationship_names => [@story_property_name])
    add_card_to_tree(@tree, [@story_1], :root)
    add_card_to_tree(@tree, [@bug_1, @bug_2], @story_1)

    @plv = setup_project_variable(@project, :name => 'main story', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => @type_story, :value => @story_1, :properties => [@story_property_name])
    navigate_to_tree_view_for(@project, @tree.name)
    set_tree_filter_for(@type_story, 0, :property => @story_property_name, :plv_value => plv_display_name(@plv.name))
    @saved_view1 = create_card_list_view_for(@project, 'bugs for main story tree')

    navigate_to_hierarchy_view_for(@project, @tree)
    set_tree_filter_for(@type_story, 0, :property => @story_property_name, :plv_value => plv_display_name(@plv.name))
    click_exclude_card_type_checkbox(@type_story.name)

    @saved_view2 = create_card_list_view_for(@project, 'bugs for main story hierarchy')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(@saved_view2)
  end
end
