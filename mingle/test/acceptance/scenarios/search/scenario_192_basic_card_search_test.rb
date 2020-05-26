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

# Tags: search
class Scenario192BasicCardSearchTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session

    @project = create_project(:prefix => 'scenario_192', :users => [users(:admin)])
    epicstory = 'Epic story'
    defect = 'Defect'
    setup_card_type(@project, epicstory)
    setup_card_type(@project, defect)
    @card_16 = {:number => '16', :name => 'card without tagging', :card_type => epicstory}
    @card_17 = {:number => '17',
      :name => 'Add url for feed',
      :description => '<h2>web address</h2>', :card_type => defect
    }

    @card_18 = {:number => '18', :name => 'Send an email', :description => 'mind meld', :card_type => defect}
    @card_19 = {:number => '19', :name => 'Delete', :description => 'You will be deleted', :card_type => defect}
    login_as_admin_user
  end

  def teardown
    @project.deactivate
  end

  def test_basic_card_search

    card_16 = create_card!(@card_16)
    card_17 = create_card!(@card_17)
    card_18 = create_card!(@card_18)
    card_17.add_tag('rss')
    card_17.save!

    open_card(@project, card_16.number)
    add_comment('testing is fun')
    open_card(@project, card_17.number)
    add_comment('testing comment section')
    open_card(@project, card_18.number)
    add_comment('https://www.google.com')
    @browser.run_once_full_text_search
    search_with('without tagging')
    assert_card_present_in_search_results(@card_16)

    search_with('rss')
    assert_card_present_in_search_results(@card_17)
    assert_card_not_present(@card_18)
    assert_card_not_present(@card_16)
    assert_text_in_search_text_box('rss')

    search_with('testing fun') # story 13264
    assert_card_present_in_search_results(@card_16)
    assert_card_not_present(@card_17)
    assert_card_not_present(@card_18)
    assert_text_in_search_text_box('testing fun')

    search_with('testing') # story 13264
    assert_card_present_in_search_results(@card_16)
    assert_card_present_in_search_results(@card_17)
    assert_card_not_present(@card_18)
    assert_text_in_search_text_box('testing')

    search_with('web')
    assert_card_present_in_search_results(@card_17)
    assert_card_not_present(@card_18)
    assert_card_not_present(@card_16)


    search_with('form')
    assert_card_not_present(@card_18)
    assert_card_not_present(@card_16)
    assert_search_message_states_no_results_returned('form')

    search_with('url')
    assert_card_present_in_search_results(@card_17)
    assert_card_not_present(@card_18)
    assert_card_not_present(@card_16)

    click_card_link_on_search_result(card_17)
    @browser.assert_element_not_present('notice')

    type_search_text("##{card_18.number}")
    @browser.click(search_button)
    @browser.wait_for_element_present("css=#card_show_lightbox_content .card-number")
    @browser.assert_text("css=#card_show_lightbox_content .card-number", "##{card_18.number}")
    @browser.click("css=#card_show_lightbox_content .close-button")

    search_with("#") # bug 1605
    assert_card_present_in_search_results(@card_16)
    assert_card_present_in_search_results(@card_17)
    assert_card_present_in_search_results(@card_18)

    # Verify stemming works
    search_with("tag")
    assert_count_of_search_results_found("1")
    assert_card_present_in_search_results(@card_16)

    # Search by card description
    open_card_for_edit(@project,card_16.number)
    type_card_description("Testing description")
    save_card
    @browser.run_once_full_text_search
    search_with("description")
    assert_card_present(@card_16)

    # Search by card type
    search_with('type:Defect')
    assert_count_of_search_results_found("2")
    assert_card_present_in_search_results(@card_17)
    assert_card_present_in_search_results(@card_18)

    search_with('type:"Epic story"')
    assert_count_of_search_results_found("1")
    assert_card_present_in_search_results(@card_16)

    search_with('type:Defect email')
    assert_count_of_search_results_found("1")
    assert_card_present_in_search_results(@card_18)

  end

  #Story 13202
  def test_user_can_search_cards_imported_from_excel
    new_project = create_project(:prefix => 'scenario_192_1', :admins => [users(:admin), users(:proj_admin)])
    navigate_to_card_list_for(new_project)
    header_row  = ['number', 'name', 'type']
    card_data   = [['1', 'Testing search', 'card1'], ['2', 'New feature', 'card2'], ['3', 'Old feature', 'story']]
    import(excel_copy_string(header_row, card_data))
    @browser.run_once_full_text_search
    search_with("feature")
    assert_count_of_search_results_found("2")
    assert_text_present('New feature')
    assert_text_present('Old feature')

  end

  def test_search_should_not_return_the_card_which_is_deleted
    card_19 = create_card!(@card_19)
    @browser.run_once_full_text_search
    navigate_to_card_list_for(@project)
    search_with('delete')
    assert_count_of_search_results_found("1")
    assert_card_present_in_search_results(@card_19)
    delete_card(@project,card_19)
    @browser.run_once_full_text_search
    search_with('delete')
    assert_search_message_states_no_results_returned('delete')
  end
end
