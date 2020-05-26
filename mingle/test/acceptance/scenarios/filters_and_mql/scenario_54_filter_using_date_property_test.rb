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

# Tags: scenario, cards, card-list, filters, date-property, #2514, #2557, #2627
class Scenario54FilterUsingDatePropertyTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access
  BUG = 'Bug'
  STORY = 'Story'
  
  PRIORITY = 'Priority'
  STORY_STATUS = 'Story Status'
  BUG_STATUS = 'Bug Status'
  CLOSED_ON = 'Closed On'
  
  ANY = '(any)'
  NOTSET = '(not set)'
  TODAY = '(today)'
  
  TYPE = 'Type'
  TAG_1 = 'story bug'
  
  OWNER = 'Owner'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @non_team_member = users(:existingbob)
    @non_admin_user = users(:longbob)
    @admin = users(:admin)
    @team_member_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_54', :users => [@admin, @team_member_user, @non_admin_user])
    login_as_admin_user
    
    setup_property_definitions(PRIORITY => ['high','medium','low'], BUG_STATUS => ['new', 'open', 'closed'], STORY_STATUS => ['new', 'assigned', 'close'])
    setup_user_definition(OWNER)
    setup_date_property_definition(CLOSED_ON)
    
    setup_card_type(@project, STORY, :properties => [STORY_STATUS, PRIORITY, OWNER, CLOSED_ON])
    setup_card_type(@project, BUG, :properties => [BUG_STATUS, PRIORITY, OWNER, CLOSED_ON])

    @card_1 = create_card!(:name => 'card without no property set', :card_type  => STORY, CLOSED_ON => '22 jan 2001', OWNER => @admin.id).tag_with(TAG_1)
    @card_2 = create_card!(:name => 'story1', :card_type  => STORY, PRIORITY  => 'high', CLOSED_ON => '21 jan 2001', STORY_STATUS  =>  'new', OWNER => @non_admin_user.id).tag_with(TAG_1)
    @card_3 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'low', CLOSED_ON => '20 jan 2001', STORY_STATUS  =>  'assigned', OWNER => @team_member_user.id)
    @card_4 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high', CLOSED_ON => '19 jan 2001', BUG_STATUS  =>  'new', OWNER => @admin.id).tag_with(TAG_1)
    @card_5 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium', CLOSED_ON => '18 jan 2001', BUG_STATUS  =>  'new', OWNER => @non_admin_user.id)
    @card_6 = create_card!(:name => 'bug3', :card_type  => BUG, PRIORITY  => 'low', CLOSED_ON => '17 jan 2001', BUG_STATUS  =>  'closed', OWNER => @team_member_user.id)
    @card_7 = create_card!(:name => 'new bug3', :card_type  => BUG, BUG_STATUS  =>  'new', CLOSED_ON => '16 jan 2001', OWNER => @team_member_user.id)
        
    navigate_to_card_list_for(@project)
  end
  
  def teardown
    @project.deactivate
  end
  
  def test_should_be_able_to_filter_by_dates
    story_1 = create_card!(:name => 'story1', :card_type  => STORY, PRIORITY  => 'high', CLOSED_ON => '21 jan 2001', STORY_STATUS  =>  'new', OWNER => @non_admin_user.id).tag_with(TAG_1)
    story_2 = create_card!(:name => 'story2', :card_type  => STORY, PRIORITY  => 'low', CLOSED_ON => '20 jan 2001', STORY_STATUS  =>  'assigned', OWNER => @team_member_user.id)
    bug_1 = create_card!(:name => 'bug1', :card_type  => BUG, PRIORITY  => 'high', CLOSED_ON => '19 jan 2001', BUG_STATUS  =>  'new', OWNER => @admin.id).tag_with(TAG_1)
    bug_2 = create_card!(:name => 'bug2', :card_type  => BUG, PRIORITY  => 'medium', CLOSED_ON => '18 jan 2001', BUG_STATUS  =>  'new', OWNER => @non_admin_user.id)
    bug_3 = create_card!(:name => 'bug3', :card_type  => BUG, PRIORITY  => 'low', CLOSED_ON => '17 jan 2001', BUG_STATUS  =>  'closed', OWNER => @team_member_user.id)
    
    
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][is before][19 Jan 2001]")
    assert_cards_not_present(story_1, story_2)
    assert_cards_present(bug_2, bug_3)
    
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][is after][19 Jan 2001]")
    assert_cards_not_present(bug_2, bug_3)
    assert_cards_present(story_1, story_2)
    
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][is not][19 Jan 2001]")
    assert_cards_not_present(bug_1)
    assert_cards_present(story_1, story_2, bug_2, bug_3)
    
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][is][19 Jan 2001]")
    assert_cards_present(bug_1)
    assert_cards_not_present(story_1, story_2, bug_2, bug_3)
  end
  
  def test_filtering_date_property_with_today_as_a_value_with_different_operators
    story_1 = create_card!(:name => 'story1', :card_type  => STORY, CLOSED_ON => '21 jan 2001')
    story_2 = create_card!(:name => 'story2', :card_type  => STORY, CLOSED_ON => '20 jan 2001')
    bug_1 = create_card!(:name => 'bug1', :card_type  => BUG, CLOSED_ON => '19 jan 2001')
    bug_2 = create_card!(:name => 'bug2', :card_type  => BUG, CLOSED_ON => '18 jan 2001')
    bug_3 = create_card!(:name => 'bug3', :card_type  => BUG, CLOSED_ON => '17 jan 2001')

    fake_now(2001, 01, 19)
    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => CLOSED_ON, :value => TODAY, :operator => 'is before')
    assert_cards_not_present(story_2, story_1)
    assert_cards_present(bug_2, bug_3)
    
    select_is_after(1)
    assert_cards_not_present(bug_3, bug_2)
    assert_cards_present(story_1, story_2)    
    
    select_is_not(1)
    assert_cards_not_present(bug_1)
    assert_cards_present(story_2, story_1, bug_2, bug_3)
    
    select_is(1)
    assert_cards_present(bug_1)
    assert_cards_not_present(bug_3, bug_2, story_2, story_1)
  ensure
    @browser.reset_fake
  end
  
  def test_casing_of_today_is_insensitive
    story_1 = create_card!(:name => 'story1', :card_type  => STORY,CLOSED_ON => '21 jan 2001')
    bug_1 = create_card!(:name => 'bug1', :card_type  => BUG, CLOSED_ON => '19 jan 2001')

    fake_now(2001, 01, 19)
    navigate_to_card_list_for(@project)
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][is][(TOdaY)]")
    assert_cards_not_present(story_1)
    assert_cards_present(bug_1)
  ensure
    @browser.reset_fake
  end
  
  def test_should_be_able_to_change_time_zone_when_holding_saved_view_with_today_as_date_filter
    bug_1 = create_card!(:name => 'bug1', :card_type  => BUG, CLOSED_ON => '19 jan 2001')
    bug_2 = create_card!(:name => 'bug2', :card_type  => BUG, CLOSED_ON => '18 jan 2001')
    fake_now(2001, 01, 19, 8)
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][is][(today)]")
    saved_view_cards_today = create_card_list_view_for(@project, 'cards today')
    assert_cards_present(bug_1)
    navigate_to_project_admin_for(@project)
    set_project_time_zone('(GMT-10:00) Hawaii')
    assert_notice_message("Project was successfully updated.")
    open_saved_view('cards today')
    assert_cards_present(bug_2)
  ensure
    @browser.reset_fake
  end
  
  def test_casing_on_operators_is_before_and_is_after_and_check_the_filter_reflect_the_same
    story_1 = create_card!(:name => 'story1', :card_type  => STORY, CLOSED_ON => '21 jan 2001')
    story_2 = create_card!(:name => 'story2', :card_type  => STORY, CLOSED_ON => '20 jan 2001')
    bug_1 = create_card!(:name => 'bug1', :card_type  => BUG, CLOSED_ON => '19 jan 2001')
    bug_2 = create_card!(:name => 'bug2', :card_type  => BUG, CLOSED_ON => '18 jan 2001')
    bug_3 = create_card!(:name => 'bug3', :card_type  => BUG, CLOSED_ON => '17 jan 2001')
    
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][Is BeFore][19 Jan 2001]")
    assert_cards_not_present(story_2, story_1)
    assert_cards_present(bug_3, bug_2)
    assert_filter_operator_set_to(1, 'is before')
        
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][Is AfTeR][19 Jan 2001]")
    assert_cards_not_present(bug_2, bug_3)
    assert_cards_present(story_2, story_1)
    assert_filter_operator_set_to(1, 'is after')
    
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][Is leSs THan][19 Jan 2001]")
    assert_cards_not_present(story_2, story_1)
    assert_cards_present(bug_2, bug_3)
    assert_filter_operator_set_to(1, 'is before')
    
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][Is GReateR ThaN][19 Jan 2001]")
    assert_cards_not_present(bug_2, bug_3)
    assert_cards_present(story_2, story_1)
    assert_filter_operator_set_to(1, 'is after')
  end
  
  def test_not_set_is_not_available_for_is_before_and_is_after
    fake_now(2001, 01, 19)
    navigate_to_card_list_for(@project)
    add_new_filter
    set_the_filter_property_option(1, CLOSED_ON)
    select_is_before(1)
    assert_filter_value_not_present_on(1, :property_values => [NOTSET])
    
    select_is_after(1)
    assert_filter_value_not_present_on(1, :property_values => [NOTSET])
    
    select_is_not(1)
    assert_filter_value_present_on(1, :property_values => [NOTSET])
    
    select_is(1)
    assert_filter_value_present_on(1, :property_values => [NOTSET])
    
    set_the_filter_value_option(1, NOTSET)
    assert_filter_operator_not_present(1, :operators => ['is before', 'is after'])
    assert_filter_operator_present(1, :operators => ['is', 'is not'])
    
    set_the_filter_value_option(1, TODAY)
    assert_filter_operator_present(1, :operators => ['is', 'is not', 'is before', 'is after'])
  ensure
    @browser.reset_fake
  end
  
  def test_saved_views_reflect_the_filter_set_for_dates

    story_2 = create_card!(:name => 'story2', :card_type  => STORY, CLOSED_ON => '20 jan 2001')
    bug_1 = create_card!(:name => 'bug1', :card_type  => BUG, CLOSED_ON => '19 jan 2001')
    bug_2 = create_card!(:name => 'bug2', :card_type  => BUG, CLOSED_ON => '18 jan 2001')
        
    set_filter_by_url(@project, "filters[]=[#{CLOSED_ON}][is before][19 Jan 2001]")
    tab_cards_before_19jan = create_card_list_view_for(@project, 'before 19th jan')
    navigate_to_favorites_management_page_for(@project)
    toggle_tab_for_saved_view(tab_cards_before_19jan)
    click_tab('before 19th jan')
    assert_filter_operator_set_to(1, 'is before')
    assert_cards_not_present(story_2, bug_1)
    assert_cards_present(bug_2)
  end
  
  #bug 2514
  def test_date_property_does_not_hold_value_in_dropdown_list_in_filters
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{CLOSED_ON}][is][21 Jan 2001]")
    navigate_to_project_admin_for(@project)
    set_project_date_format('dd/mm/yyyy')
    click_all_tab
    assert_filter_value_not_present_on(1, :property_values => ['21 Jan 2001'])
  end
  
  #bug 2557
  def test_invalid_date_in_filter_link_gives_proper_error_message
    set_filter_by_url(@project, "filters[]=[Type][is][#{STORY}]&filters[]=[#{CLOSED_ON}][is][31 Feb 2001]")
    assert_error_message("Filter is invalid. Property (<b>)?#{CLOSED_ON} 31 Feb 2001(</b>)? is an invalid date. Enter dates in (<b>)?dd mmm yyyy(</b>)? format or enter existing project variable which is available for this property.")
  end
  
  #bug 2627
  def test_filtering_date_property_is_any_does_not_show_ignore_error_message
    story_1= create_card!(:name => 'story_1', :card_type  => STORY, CLOSED_ON => '22 jan 2001')
    bug_1 = create_card!(:name => 'new bug3', :card_type  => BUG, CLOSED_ON => '16 jan 2001')
    navigate_to_card_list_for(@project)
        
    set_the_filter_value_option(0, BUG)
    add_new_filter 
    set_the_filter_property_and_value(1, :property => CLOSED_ON, :value => TODAY, :operator => 'is not')
    set_the_filter_property_and_value(1, :property => CLOSED_ON, :value => ANY, :operator => 'is')
  
    @browser.assert_text_not_present("Filter is invalid")
    @browser.assert_text_not_present("':ignore'")
  end

end
