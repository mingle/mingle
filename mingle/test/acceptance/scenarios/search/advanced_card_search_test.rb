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

class AdvancedCardSearchTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project
    login_as_admin_user
  end

  def test_search_for_text_card_property_returns_card_with_searched_property_value_and_highlights_found_property
    @project.with_active_project do |project|
      create_allow_any_text_property('Notes')
      @first_story = project.cards.create!(:name => 'First story', :card_type_name => 'Card', :cp_notes => 'I love Elastic Search')
    end

    run_all_search_message_processors
    open_project @project
    search_with('I love Elastic Search')
    assert_card_present_in_search_results(@first_story)
    @browser.assert_text_present_in(css_locator('.properties-and-tags'), 'notes: I love Elastic Search')
  end

  def test_search_for_date_card_property_doesnt_return_any_matches
    @project.with_active_project do |project|
      create_date_property('Closed')
      @first_story = project.cards.create!(:name => 'First story', :card_type_name => 'Card', :cp_closed => '17-JUL-2012')
    end

    run_all_search_message_processors
    open_project @project
    search_with('2012')
    assert_no_search_results_found
  end

  def test_search_for_user_property_finds_and_highlights_results
    @project.with_active_project do |project|
      bob = User.find_by_email('bob@email.com')
      project.add_member bob

      setup_user_definition 'Owner'
      @first_story = project.cards.create!(:name => 'First story', :card_type_name => 'Card', :cp_owner => bob)
    end

    run_all_search_message_processors
    open_project @project
    search_with('bob')
    assert_card_present_in_search_results(@first_story)
    @browser.assert_text_present_in(css_locator('.properties-and-tags'), 'owner: bob')
  end

  def test_search_for_numeric_property_finds_results
    @project.with_active_project do |project|
      setup_managed_number_list_definition 'Estimate', [1, 3, 5]
      @first_story = project.cards.create!(:name => 'First story', :card_type_name => 'Card', :cp_estimate => '3')
    end

    run_all_search_message_processors
    open_project @project
    search_with('3')
    assert_card_present_in_search_results(@first_story)
    @browser.assert_text_present_in(css_locator('.properties-and-tags'), 'estimate: 3')
  end

  def test_search_using_property_name_and_value_is_case_insensitive
    @project.with_active_project do |project|
      setup_property_definitions :size => ['S', 'M', 'L']
      @first_story = project.cards.create!(:name => 'First story', :card_type_name => 'Card', :cp_size => 'M')
    end

    run_all_search_message_processors
    open_project @project
    search_with('SIZE:m')
    assert_card_present_in_search_results(@first_story)
    @browser.assert_text_present_in(css_locator('.properties-and-tags'), 'size: M')
  end
end
