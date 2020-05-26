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

# Tags: story, #763, navigation, cards, card-list, transitions
class Story763PrevNextShowCardNavigationTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_project_member
    @project = create_project(:prefix => 'story763', :users => [users(:project_member)])
    setup_property_definitions :Iteration => [1, 2], :Status => ['playing']
    
    @card1 = create_card!(:name => 'first card', :iteration => '1')
    @card2 = create_card!(:name => 'second card', :iteration => '2')
    @funky_card = create_card!(:name => 'funky card')
    @funky_card.cp_iteration = '2'
    @funky_card.save!
    
    @play = create_transition @project, 'Play', :required_properties => {'iteration' => '1'}, :set_properties => {'status' => 'playing'}
  end
  
  def test_prev_next_links_display_and_work_when_navigating_to_show_card_from_card_list
    navigate_to_card_list_for @project, ['iteration']
    click_card_list_column_and_wait 'Iteration'
    click_card_on_list(@funky_card)
    
    # basic prev/next navigation
    @browser.assert_text_present '2 of 3'
    @browser.click_and_wait "next-link"
    assert_on_card(@project, @card2)
    @browser.assert_text_present '3 of 3'
    @browser.click_and_wait "next-link"
    assert_on_card(@project, @card1)
    @browser.assert_text_present '1 of 3'
    @browser.click_and_wait "previous-link"
    assert_on_card(@project, @card2)
    @browser.assert_text_present '3 of 3'    
    @browser.click_and_wait "previous-link"
    assert_on_card(@project, @funky_card)
    @browser.assert_text_present '2 of 3' 
    
    # edit-save preserves navigation
    click_edit_link_on_card
    @browser.type 'card[name]', 'a new funky card name for number 2'
    save_card
    assert_on_card(@project, @funky_card)
    @browser.assert_text_present '2 of 3'
    
    # edit-cancel preserves navigation
    @browser.click_and_wait "next-link"
    click_edit_link_on_card
    @browser.type 'card[name]', 'a CRAZY new name for #3'
    @browser.click_and_wait "link=Cancel"
    assert_on_card(@project, @card2)
    @browser.assert_text_present '3 of 3'
    @browser.assert_text_not_present 'a CRAZY new name for #3'
    
    # executing transition preserves navigation
    @browser.click_and_wait "next-link"
    @browser.assert_text_present '1 of 3'
    @browser.assert_element_present 'link=Play'
    click_transition_link_on_card(@play)
    assert_on_card(@project, @card1)
    @browser.assert_text_present '1 of 3'
    assert_properties_set_on_card_show('status' => 'playing')

    # and delete does what ???         
  end
end
