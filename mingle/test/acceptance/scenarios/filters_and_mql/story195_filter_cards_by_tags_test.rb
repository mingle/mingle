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

# Tags: story, #195, filters, card-list
class Story195FilterCardsByTagsTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_project_member
    @project = create_project(:prefix => 'story195', :users => [users(:project_member)])
    setup_property_definitions :iteration => [1, 2], :priority => ['high', 'low']
    
    @card_100 =create_card!(:number => 100, :name => "100th card", :iteration => '1', :priority => 'high')
    @card_101 =create_card!(:number => 101, :name => "101st card", :iteration => '1', :priority => 'low')
    @card_102 =create_card!(:number => 102, :name => "102nd card", :iteration => '2', :priority => 'high')
    
    navigate_to_card_list_showing_iteration_and_status_for(@project)
  end
  
  def test_apply_filters_should_filter_listed_cards
    filter_card_list_by(@project, :iteration => 1)
    
    @browser.assert_text_present '100th card'
    @browser.assert_text_present '101st card'
    @browser.assert_text_not_present '102nd card'

    assert_properties_present_on_card_list_filter :iteration => '1'
    
    # add & apply 'priority-high' filter
    
    filter_card_list_by(@project, :priority => 'high', :keep_filters => true)
    
    # test for pretty url. not been done yet
    #@browser.assert_location '/first_project/cards?tagged_with[]=iteration-1&tagged_with[]=priority-high'    
    
    @browser.assert_text_present '100th card'
    @browser.assert_text_not_present '101st card'
    @browser.assert_text_not_present '102nd card'
     
   # remove iteration-1 filter & apply
    reset_view
    filter_card_list_by(@project, :priority => 'high')
     
    @browser.assert_text_present '100th card'
    @browser.assert_text_not_present '101st card'
    @browser.assert_text_present '102nd card'
   
    # reset filter
    reset_view
    @browser.assert_text_present '100th card'
    @browser.assert_text_present '101st card'
    @browser.assert_text_present '102nd card'
  end
  
  def test_apply_filter_should_not_change_sorting_order
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    @browser.with_ajax_wait do
      @browser.click "link=#"
    end
    cards.assert_row_values_for_card(1, @card_100)
    cards.assert_row_values_for_card(2, @card_101)    
       
    filter_card_list_by(@project, :iteration => 1)
    
    cards.assert_row_values_for_card(1, @card_100)
    cards.assert_row_values_for_card(2, @card_101)
  end
  
  def test_sort_cards_should_keep_existing_filting_rules
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'], 1, 1)
    filter_card_list_by(@project, :iteration => 1)

    cards.assert_row_values_for_card(2, @card_100)
    cards.assert_row_values_for_card(1, @card_101)    
    @browser.with_ajax_wait do
      @browser.click "link=#"
    end
    cards.assert_row_values_for_card(1, @card_100)
    cards.assert_row_values_for_card(2, @card_101)
    @browser.assert_text_not_present "102nd card"
  end
  
end
