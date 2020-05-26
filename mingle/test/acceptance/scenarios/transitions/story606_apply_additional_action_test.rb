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

# Tags: story, #606, transitions
class Story606ApplyAdditionalActionTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'story606', :users => [users(:project_member)])
    setup_property_definitions :status => ['fixed', 'closed']    
    login_as_project_member
  end
  
  def test_apply_additional_action_to_multiple_cards
    @project.with_active_project do
      @card1 =create_card!(:name => 'card 1')
      @card1.update_attribute(:cp_status, 'fixed')
      @card2 =create_card!(:name => 'card 2')
      @card3 =create_card!(:name => 'card 3')
      @card3.update_attribute(:cp_status, 'fixed')
    
      @close = create_transition @project,'close', :required_properties => { :status => 'fixed'}, :set_properties => {:status => 'closed'}
    end
    
    navigate_to_card_list_for(@project)
  
    @browser.click 'checkbox_0'
    @browser.click 'checkbox_2'
    execute_bulk_transition_action(@close)
    @browser.wait_for_element_visible 'notice'
    @browser.assert_element_matches 'notice', /(<b>)?#{@close.name}(<\/b>)? successfully applied to cards #3, #1/
    
    @project.with_active_project do
      assert_equal 'closed', @card1.reload.cp_status
      assert_equal 'closed', @card3.reload.cp_status
    end  
  end
    
  def test_transition_made_not_available_by_another_user
    @project.with_active_project do
      @card1 =create_card!(:name => 'card 1')
      @card1.update_attribute(:cp_status, 'fixed')
      @card2 =create_card!(:name => 'card 2')
      @card3 =create_card!(:name => 'card 3')
      @card3.update_attribute(:cp_status, 'fixed')
    
      @close = create_transition @project,'close', :required_properties => { :status => 'fixed'}, :set_properties => {:status => 'closed'}
    end
    
    navigate_to_card_list_for(@project)
    
    @browser.click 'checkbox_0'
    @browser.click 'checkbox_2'
    open_bulk_transitions
    
    @project.with_active_project do
      @card3.update_attribute(:cp_status, 'open')
    end  
    
    @browser.click("#{@close.html_id}_link")
    @browser.wait_for_page_to_load
    
    @browser.wait_for_element_visible 'error'
    @browser.assert_element_matches 'error', /(<b>)?#{@close.name}(<\/b>)? is not applicable to Card #3/
    
    @project.with_active_project do
      assert_equal 'fixed', @card1.reload.cp_status
      assert_equal 'open', @card3.reload.cp_status
    end  
  end  
  
  def test_apply_additional_action_to_single_card
    @project.with_active_project do    
      @card1 =create_card!(:name => 'card 1')
      @card1.update_attribute(:cp_status, 'fixed')
      @card2 =create_card!(:name => 'card 2')
      @card3 =create_card!(:name => 'card 3')
      @card3.update_attribute(:cp_status, 'fixed')

      @close = create_transition @project,'close', :required_properties => { :status => 'fixed'}, :set_properties => {:status => 'closed'}

    end
    
    navigate_to_card_list_for(@project)
    
    @browser.click 'checkbox_2'
    execute_bulk_transition_action(@close)
    @browser.wait_for_element_visible 'notice'
    @browser.assert_element_matches 'notice', /(<b>)?#{@close.name}(<\/b>)? successfully applied to card #1/
    
    @project.with_active_project do
      assert_not_equal 'closed', @card3.reload.cp_status
      assert_equal 'closed', @card1.reload.cp_status
    end  
  end  

end
