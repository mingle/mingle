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

# Tags: story, #524, gridview
class Story524ViewCardsInSwimmingLanesTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'story524', :users => [users(:project_member)])
    setup_property_definitions :iteration => [1, 2], :old_type => ['story'], :size => [2, 4]
    login_as_project_member
    @card1 =create_card!(:name=>'card1')
    @card1.update_attributes(:cp_iteration => '1', :cp_old_type => 'story', :cp_size => '2')
    @card2 =create_card!(:name=>'card2')
    @card2.update_attributes(:cp_iteration => '2', :cp_old_type => 'story', :cp_size => '2')
    @card3 =create_card!(:name=>'card3')
    @card3.update_attributes(:cp_size => '4')
  end
      
  def test_switch_card_list_view_to_swimming_lanes
    assert_can_switch_card_list_view_to_swimming_lanes_and_can_switch_back
    assert_can_select_swim_lanes_group_in_lanes_view
    assert_can_save_the_lanes_view
  end
  
  def assert_can_switch_card_list_view_to_swimming_lanes_and_can_switch_back
    navigate_to_card_list_for(@project, ['iteration', 'old_type'])
    filter_card_list_by(@project, 'old_type' => 'story')
    
    @browser.click_and_wait 'link=Grid'
    assert_properties_present_on_card_list_filter 'old_type' => 'story'
    assert_card_in_lane('ungrouped', '', @card1.number)
    assert_card_in_lane('ungrouped', '', @card2.number)
    assert_card_not_in_lane('ungrouped', '', @card3.number)
    
    @browser.click_and_wait 'link=List'
    assert_properties_present_on_card_list_filter 'old_type' => 'story'
    @browser.assert_column_present 'cards', 'iteration'
    @browser.assert_column_present 'cards', 'old_type'
  end
  
  def assert_can_select_swim_lanes_group_in_lanes_view
    reset_view
    @browser.click_and_wait 'link=Grid'
    
    group_columns_by('iteration')
    assert_card_in_lane('iteration', '', @card3.number)
    assert_card_in_lane('iteration', '1', @card1.number)
    assert_card_in_lane('iteration', '2',  @card2.number)
    @browser.assert_value 'name=group_by[lane]', 'iteration'  
    
    group_columns_by('size')
    assert_card_in_lane('size', '2', @card1.number)
    assert_card_in_lane('size', '2', @card2.number)
    assert_card_in_lane('size', '4', @card3.number)
    @browser.assert_value 'name=group_by[lane]', 'size'
  end
  
  def assert_can_save_the_lanes_view
    group_columns_by('iteration')
    
    assert_card_in_lane('iteration', '', @card3.number)    
    
    filter_card_list_by(@project, 'old_type' => 'story')
    create_card_list_view_for(@project, 'saved lanes view')
    @browser.click_and_wait 'link=saved lanes view'
    assert_include "view=saved+lanes+view", @browser.get_location
    
    assert_card_in_lane('iteration', '1', @card1.number)
    assert_card_in_lane('iteration', '2', @card2.number)
    @browser.assert_value 'name=group_by[lane]', 'iteration'    
  end

end
