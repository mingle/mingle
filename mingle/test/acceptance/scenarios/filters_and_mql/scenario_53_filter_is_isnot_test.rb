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

# Tags: filters
class Scenario53FilterIsIsnotTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  BUG = 'Bug'
  STORY = 'Story'
  CARD = 'Card'
  
  PRIORITY = 'Priority'
  STORY_STATUS = 'Story Status'
  BUG_STATUS = 'Bug Status'
  
  ANY = '(any)'
  NOTSET = '(not set)'
  
  TYPE = 'Type'
  TAG_1 = 'story bug'
  
  OWNER = 'Owner'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_team_member = users(:existingbob)
    @non_admin_user = users(:longbob)
    
    @admin = users(:admin)
    @proj_admin = users(:proj_admin)
    @team_member = users(:project_member)
    
    @project = create_project(:prefix => 'scenario_53', :users => [@admin, @proj_admin, @team_member])
    login_as_admin_user
    
    setup_property_definitions(PRIORITY => ['high','medium','low'], BUG_STATUS => ['new', 'open', 'closed'], STORY_STATUS => ['new', 'assigned', 'close'])
    setup_user_definition(OWNER)
    setup_card_type(@project, STORY, :properties => [STORY_STATUS, PRIORITY, OWNER])
    setup_card_type(@project, BUG, :properties => [BUG_STATUS, PRIORITY, OWNER])
          
    navigate_to_card_list_for(@project)
  end
    
  def test_is_not_will_display_cards_otherthan_the_filter_in_card_list_view
    story1 = create_card!(:name => 'story1', :card_type  => STORY, OWNER => @admin.id).tag_with(TAG_1)
    story2 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'high', STORY_STATUS  =>  'new')
    story3 = create_card!(:name => 'story3', :card_type  => STORY, PRIORITY  => 'low', STORY_STATUS  =>  'assigned')

    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high', BUG_STATUS  =>  'new')
    bug2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium', BUG_STATUS  =>  'new')
    bug3 = create_card!(:name => 'bug3', :card_type  => BUG, PRIORITY  => 'low', BUG_STATUS  =>  'closed')

    select_is_not(0)
    set_the_filter_value_option(0, STORY)
    assert_cards_present(bug1, bug2, bug3)
    assert_cards_not_present(story1, story2, story3)
    
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'high', :operator => 'is not')
    assert_cards_present(bug2, bug3)
    assert_cards_not_present(story1, story2, story3, bug1)
  end
  
  # Bug 2644.
  def test_is_not_and_is_should_not_return_all_cards
    story1 = create_card!(:name => 'story1', :card_type  => STORY)
    story2 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'high')
    story3 = create_card!(:name => 'story3', :card_type  => STORY, PRIORITY  => 'low')
    
    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high')
    bug2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium')
    bug3 = create_card!(:name => 'bug3', :card_type  => BUG, PRIORITY  => 'low')

    set_the_filter_value_option(0, STORY)
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'high')
    add_new_filter
    set_the_filter_property_and_value(2, :property => PRIORITY, :value => 'low', :operator => 'is not')
    assert_cards_present(story1, story2)
    assert_cards_not_present(story3, bug1, bug2, bug3)
  end
  
  
  def test_add_remove_columns_showup_appropiate_properties_as_per_filter_condition
    story1 = create_card!(:name => 'story1', :card_type  => STORY, PRIORITY  => 'high', STORY_STATUS  =>  'new')
    story2 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'low', STORY_STATUS  =>  'assigned', OWNER => @proj_admin.id)

    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high', BUG_STATUS  =>  'new', OWNER => @admin.id)
    bug2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium', BUG_STATUS  =>  'new', OWNER => @team_member.id)

    # disassociate Story Status property from card types other than Bug and Story
    open_edit_card_type_page(@project, CARD)
    uncheck_properties_required_for_card_type(@project, [STORY_STATUS])
    save_card_type
    click_continue_to_update
    navigate_to_card_list_for(@project)
    
    # the real test begins here
    set_the_filter_value_option(0, STORY)
    select_is_not(0)
    assert_properties_present_on_add_remove_column_dropdown(@project, [PRIORITY, BUG_STATUS, OWNER, 'Type', 'Created by', 'Modified by'])
    assert_properties_not_present_on_add_remove_column_dropdown(@project, [STORY_STATUS])
  end
  
  def test_link_to_url_is_case_insensitive
    story1 = create_card!(:name => 'story1', :card_type  => STORY)
    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high')
    bug2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium')
    
    set_filter_by_url(@project, "filters[]=[Type][Is nOT][#{STORY}]")
    assert_cards_present(bug1, bug2)
    assert_cards_not_present(story1)
  end
  
  def test_saved_views_with_is_not_operator
    story1 = create_card!(:name => 'story1', :card_type  => STORY)
    story2 = create_card!(:name => 'story2', :card_type  => STORY)
    
    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high')
    bug2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium')

    set_filter_by_url(@project, "filters[]=[Type][is not][#{STORY}]")
    assert_cards_present(bug1, bug2)
    tab_other_than_story = create_card_list_view_for(@project, 'other than story')
    
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]")
    assert_cards_present(story1, story2)
    tab_story = create_card_list_view_for(@project, 'stories')
    
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_other_than_story, tab_story)
    
    click_all_tab
    select_is_not(0)
    set_the_filter_value_option(0, STORY)
    
    assert_tab_highlighted('All')
    assert_cards_present(bug1, bug2)
    select_is(0)
    assert_tab_highlighted('All')
    assert_cards_present(story1, story2)
  end
  
  def test_filter_isnot_with_notset_value
    story1 = create_card!(:name => 'story1', :card_type  => STORY)
    story2 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'low')
        
    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high', BUG_STATUS  =>  'new')
    bug2 = create_card!(:name => 'bug2', :card_type  => BUG)
    
    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => NOTSET, :operator => 'is not')
    assert_cards_not_present(story1, bug2)
    assert_cards_present(story2, bug1)
  end
  
  def test_user_property_filtering_with_is_not_set
    story1 = create_card!(:name => 'story1', :card_type  => STORY, OWNER => @team_member.id)
    story2 = create_card!(:name => 'story2', :card_type  => STORY, OWNER => @proj_admin.id)
    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, OWNER => @admin.id)
    
    add_new_filter
    set_the_filter_property_and_value(1, :property => OWNER, :value => '(current user)', :operator => 'is not')
    assert_cards_present(story1, story2)
    assert_cards_not_present(bug1)
    
    saved_filter = create_card_list_view_for(@project, "saved filter")
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(saved_filter)
    
    
    login_as_proj_admin_user
    click_tab('saved filter')
    assert_cards_present(story1, bug1)
    assert_cards_not_present(story2)
    
    login_as_project_member
    click_tab('saved filter')
    assert_cards_present(story2, bug1)
    assert_cards_not_present(story1)
  end
  
  def test_filter_isnot_remains_with_non_ajax_calls_like_link_to_this_page
    story1 = create_card!(:name => 'story1', :card_type  => STORY, PRIORITY  => 'high').tag_with(TAG_1)
    bug1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high').tag_with(TAG_1)
    bug2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium')

    add_new_filter
    set_the_filter_property_and_value(1, :property => PRIORITY, :value => 'medium', :operator => 'is not')
    click_link_to_this_page
    assert_filter_operator_set_to(1, 'is not')
    assert_cards_present(story1, bug1)
    assert_cards_not_present(bug2)
    select_all
    click_edit_properties_button
    set_card_type_on_bulk_edit(STORY)
    assert_filter_operator_set_to(1, 'is not')
    assert_cards_present(story1, bug1)
    assert_cards_not_present(bug2)
  end
  
end
