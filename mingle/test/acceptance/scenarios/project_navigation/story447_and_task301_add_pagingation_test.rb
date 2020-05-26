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

# Tags: task, #301, card-list, navigation, story
class Story447AndTask301AddPagingationTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'task301', :users => [users(:project_member)])
    setup_property_definitions :iteration => [1], :priority => ['high']
    login_as_project_member
  end

  def test_go_through_cards_list_by_pagination
    batch_create_cards 30
    @browser.open "/projects/#{@project.identifier}/cards"
    @browser.assert_element_not_present "link=Previous"  
    @browser.assert_element_present "link=Next"
    @browser.assert_text_present 'card 30'
    @browser.assert_text_present 'card 6'
    @browser.assert_text_not_present 'card 5'
    @browser.click_and_wait "link=Next"
    @browser.assert_element_present "link=Previous"  
    @browser.assert_element_not_present 'link=Next'
    @browser.assert_text_not_present 'card 6'
    @browser.assert_text_present 'card 5'
    

    @browser.assert_element_not_present 'page_3'
    @browser.assert_element_present 'page_1'
    @browser.assert_element_not_present 'page_2'

    click_page_link(1)
    @browser.assert_element_not_present 'page_1'
    @browser.assert_element_present 'page_2'
    
  end

  def test_single_page_have_no_pagination_information
    batch_create_cards 10
    @browser.open "/projects/#{@project.identifier}/cards"
    @browser.assert_element_not_present "link=Previous"
    @browser.assert_element_not_present "link=Next"
    @browser.assert_element_not_present "page_1"
  end

  def batch_create_cards(count)
    (1..count).each do |index|
      card = create_card!(:number => index, :name => "card #{index}")
      card.update_attributes(:cp_iteration => '1', :cp_priority => 'high')
    end
  end
end
