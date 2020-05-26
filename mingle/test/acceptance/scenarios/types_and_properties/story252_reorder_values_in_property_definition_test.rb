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

# Tags: story, #252, properties
class Story252ReorderValuesInPropertyDefinitionTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  #the drag_and_drop test helper is not enough robust on ie yet
  does_not_work_on_ie

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session

    @project = create_project(:prefix => 'story252', :admins => [users(:proj_admin)])
    login_as_proj_admin_user

    setup_property_definitions :Iteration => ['1', '2', '3'], :Status => ['open', 'done']
    @browser.open("/projects/#{@project.identifier}")
    create_new_card(@project, :name => 'new card 1', :iteration => '1', :status => 'open')
    create_new_card(@project, :name => 'new card 2', :iteration => '2', :status => 'open')
    create_new_card(@project, :name => 'new card 3', :iteration => '3', :status => 'done')
    create_property_definition_for @project, "unused", :description => "this is an unused property definition"
    get_values
    get_cards
  end

  def test_show_correct_tagged_on_information_on_properties_list_page
    @browser.open("/projects/#{@project.identifier}/property_definitions")
    assert_can_drag_and_drop_to_reorder_the_values
    assert_the_reorder_take_effect_on_card_list
  end

  private
  def get_values
    @iteration_1 = @project.find_enumeration_value('iteration', '1')
    @iteration_2 = @project.find_enumeration_value('iteration', '2')
    @iteration_3 = @project.find_enumeration_value('iteration', '3')
    @status_open = @project.find_enumeration_value('status', 'open')
    @status_done = @project.find_enumeration_value('status', 'done')
  end

  def get_cards
    @card_1 = Card.find_by_name("new card 1")
    @card_2 = Card.find_by_name("new card 2")
    @card_3 = Card.find_by_name("new card 3")
  end

  def enum_html_id(record)
    "#{record.class.to_s.underscore}_#{record.id}"
  end

  def assert_can_drag_and_drop_to_reorder_the_values
    iteration_property_definition = @project.find_property_definition("iteration")
    @browser.click_and_wait("id=enumeration-values-#{iteration_property_definition.id}")
    @browser.assert_ordered enum_html_id(@iteration_1), enum_html_id(@iteration_2)
    @browser.assert_ordered enum_html_id(@iteration_2), enum_html_id(@iteration_3)
    @browser.with_ajax_wait do
      @browser.drag_and_drop css_locator("#drag_#{enum_html_id(@iteration_1)}"), '0,+70'
    end
    @browser.assert_ordered enum_html_id(@iteration_2), enum_html_id(@iteration_1)
    @browser.assert_ordered enum_html_id(@iteration_1), enum_html_id(@iteration_3)
    @browser.open("/projects/#{@project.identifier}/property_definitions")
    @browser.click_and_wait("id=enumeration-values-#{iteration_property_definition.id}")
    @browser.assert_ordered enum_html_id(@iteration_2), enum_html_id(@iteration_1)
    @browser.assert_ordered enum_html_id(@iteration_1), enum_html_id(@iteration_3)
  end

  def assert_the_reorder_take_effect_on_card_list
    navigate_to_card_list_showing_iteration_and_status_for @project
    click_card_list_column_and_wait 'Iteration'
    @browser.assert_ordered @card_2.html_id, @card_1.html_id
    @browser.assert_ordered @card_1.html_id, @card_3.html_id
    click_card_list_column_and_wait 'Iteration'
    @browser.assert_ordered @card_3.html_id, @card_1.html_id
    @browser.assert_ordered @card_1.html_id, @card_2.html_id
  end
end
