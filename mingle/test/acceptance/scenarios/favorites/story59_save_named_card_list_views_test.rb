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

# Tags: story, #59, card-list, cards, sort, filter, project
class Story59SaveNamedCardListViewsTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access  
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_project_member
    
    @project = create_project(:prefix => 'story59', :users => [users(:project_member), users(:admin)])
    setup_property_definitions :Iteration => [1, 2, 10], :Status => ['fixed']
    
    @card1 =create_card!(:name => 'first card')
    @card1.cp_iteration = '1'
    @card1.save!
    
    @card2 =create_card!(:name => 'second card')
    @card2.cp_iteration = '2'
    @card2.save!    
  end
  
  def test_save_named_card_list_views_and_delete_it
    navigate_to_card_list_showing_iteration_and_status_for @project
    assert_can_not_create_view_with_empty_name
    assert_saved_view_keep_sorter_filter_and_columns
    assert_invalid_view_name_shows_error
  end

  def test_updating_a_view
    navigate_to_card_list_showing_iteration_and_status_for @project
    create_card_list_view_for(@project, 'all cards')
    assert_include "view=all+cards", @browser.get_location
    filter_card_list_by(@project, :iteration => '1')
    create_card_list_view_for(@project, 'All Cards')
    assert_include "view=All+Cards", @browser.get_location
    @browser.assert_element_present 'link=All Cards'
    @browser.assert_element_not_present 'link=all cards'
    @browser.click_and_wait 'link=All Cards'
    assert_properties_present_on_card_list_filter 'iteration' => '1'
  end  
  
  def test_should_not_exist_named_view_list_when_no_named_view
    @browser.open "/projects/#{@project.identifier}"
    @browser.assert_element_not_present 'list_saved_views'
  end
   
  def test_delete_existing_named_view
    @browser.open "/projects/#{@project.identifier}/cards"  
    filter_card_list_by(@project, :iteration => '1')
    create_card_list_view_for(@project, 'test_view')
    logout
    login_as_admin_user
    @browser.open "/projects/#{@project.identifier}"
    @browser.click_and_wait "link=Project admin"
    @browser.click_and_wait 'link=Team favorites & tabs'
    @browser.assert_element_present 'favorites'
    
    destroy_view_link = list_view_delete_link_id('test_view')
    @browser.assert_element_present destroy_view_link
    @browser.click_and_wait destroy_view_link
    @browser.get_confirmation
    @browser.assert_text_present "Team favorite test_view was successfully deleted."
    @browser.assert_element_not_present destroy_view_link
    @browser.assert_element_not_present 'list_saved_views'
  end
  
  def assert_can_not_create_view_with_empty_name
    create_card_list_view_for(@project, '')    
    @browser.assert_text_present "Name can't be blank"
  end
  
  def assert_saved_view_keep_sorter_filter_and_columns
    @browser.with_ajax_wait do
      @browser.click 'link=Name'
    end
    filter_card_list_by(@project, 'iteration' => '1')
    create_card_list_view_for(@project, 'test_view')
    assert_include "view=test_view", @browser.get_location
    click_link 'test_view'
    @browser.assert_column_present 'cards', '#'
    @browser.assert_column_present 'cards', 'Name'
    @browser.assert_column_present 'cards', 'Iteration'
    @browser.assert_column_present 'cards', 'Status'
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', 'iteration', 'status'], 1, 1)
    cards.assert_ascending 'name'
    assert_properties_present_on_card_list_filter 'iteration' => '1'
  end
    
  def assert_invalid_view_name_shows_error
    @browser.open("/projects/#{@project.identifier}/cards?view=this view does not exist")
    @browser.assert_text_present "this view does not exist is not a favorite"
  end

  #bug496
  def test_saved_view_sort_in_natural_order
    navigate_to_card_list_showing_iteration_and_status_for @project
    filter_card_list_by(@project, :iteration => '1')
    create_card_list_view_for(@project, 'iteration 1')
    filter_card_list_by(@project, :iteration => '10')
    create_card_list_view_for(@project, 'iteration 10')
    filter_card_list_by(@project, :iteration => '2')
    create_card_list_view_for(@project, 'iteration 2')
    @browser.assert_element_matches 'favorites-team', /iteration 1.*iteration 2.*iteration 10/m
  end
  
  def test_saved_view_is_correct_after_filtering_is_changed
    navigate_to_card_list_showing_iteration_and_status_for @project
    filter_card_list_by(@project, 'iteration' => '1')
    assert_card_not_present @card2
    assert_card_present @card1
    create_card_list_view_for(@project, 'iteration_1')
    assert_include "view=iteration_1", @browser.get_location
    assert_card_not_present @card2
    assert_card_present @card1    
  end

end
