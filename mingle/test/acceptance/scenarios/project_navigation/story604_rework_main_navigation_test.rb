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

# Tags: story, #604, navigation, project, tagging
class Story604ReworkMainNavigationTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    
    @project = create_project(:prefix => 'story604', :admins => [users(:proj_admin)])
    setup_property_definitions :old_type => ['story', 'bug']
    
    create_tabbed_view('Stories', @project, :filters => ["[old_type][is][story]"])
    create_tabbed_view('Bugs', @project, :filters => ["[old_type][is][bug]"])
    
    login_as_proj_admin_user
    
    @card1 =create_card!(:name => 'first card', :old_type => 'story')
    @card2 =create_card!(:name => 'second card', :old_type => 'bug')
  end
  
  def test_should_show_tabbed_navigation_actions_in_header
    @browser.open "/projects/#{@project.identifier}"
    @browser.assert_element_present 'link=Bugs'
    @browser.click_and_wait "link=Stories"
    @browser.assert_location "/projects/#{@project.identifier}/cards/list?filters%5B%5D=%5Bold_type%5D%5Bis%5D%5Bstory%5D&style=list&tab=Stories"
    assert_tab_is 'Stories'
    assert_card_present @card1
    assert_card_not_present @card2

    @browser.assert_element_present 'link=Stories'
    @browser.click_and_wait "link=Bugs"
    @browser.assert_location "/projects/#{@project.identifier}/cards/list?filters%5B%5D=%5Bold_type%5D%5Bis%5D%5Bbug%5D&style=list&tab=Bugs"
    assert_tab_is 'Bugs'
    assert_card_not_present @card1
    assert_card_present @card2

    click_all_tab
    @browser.assert_location "/projects/#{@project.identifier}/cards/list?style=list&tab=All"
    assert_tab_is 'All'
    assert_card_present @card1
    assert_card_present @card2    
  end  
  
  def test_should_remember_last_view_state_when_switching_between_tabs
    @browser.open "/projects/#{@project.identifier}"
    @browser.click_and_wait "link=Stories"
    add_column_for(@project, ['old_type'])
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', 'old_type'], 1, 1)
    cards.assert_row_values(1, [1, 'first card', 'story'])
    click_tab('Bugs')
    click_tab("Stories")
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', 'old_type'], 1, 1)
    cards.assert_row_values(1, [1, 'first card', 'story'])
  end  
  
  def test_add_and_remove_tabs
    @browser.open "/projects/#{@project.identifier}/favorites/list"
    view_name = 'Stories'
    toggle_tab_for_view_named view_name
    assert_tab_not_present view_name
    toggle_tab_for_view_named view_name
    assert_tab_present view_name
  end
end    
