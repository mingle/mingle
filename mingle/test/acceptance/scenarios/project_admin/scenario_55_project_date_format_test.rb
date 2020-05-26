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

# Tags: scenario, project, date, #2623
class Scenario55ProjectDateFormatTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  CLOSED_ON_DATE_PROPERTY = 'closedOn'
  OPENED_ON_DATE_PROPERTY = 'OpenedOn'
  VALID_DATE_IN_DEFAULT_FORMAT = '06 Oct 2007'
  NOT_SET = '(not set)'
  TODAY = '(today)'
  YYYY_MM_DD = 'yyyy/mm/dd'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_55', :users => [@mingle_admin, @team_member], :admins => [@project_admin])
    setup_date_property_definition(CLOSED_ON_DATE_PROPERTY)
    setup_date_property_definition(OPENED_ON_DATE_PROPERTY)
    login_as_admin_user
  end

  def teardown
    @project.deactivate
  end

  def test_changing_date_format_in_project_does_not_affect_other_projects
    navigate_to_project_admin_for(@project)
    click_show_advanced_options_link
    select_project_date_format(YYYY_MM_DD)
    click_save_link
    navigate_to_project_admin_for(@project)
    click_show_advanced_options_link
    assert_selected_project_date_format('%Y/%m/%d')

    project_with_default_date_format = create_project(:prefix => 'default_date', :admins => [@project_admin])
    setup_date_property_definition(CLOSED_ON_DATE_PROPERTY)
    date_property_definition = project_with_default_date_format.find_property_definition_or_nil(CLOSED_ON_DATE_PROPERTY)
    open_project(project_with_default_date_format)
    card_number = create_new_card(project_with_default_date_format, :name => 'card in default format project')
    open_card(project_with_default_date_format, card_number)
    add_new_value_to_property_on_card_show(project_with_default_date_format, CLOSED_ON_DATE_PROPERTY, VALID_DATE_IN_DEFAULT_FORMAT)
    @browser.assert_element_matches(droplist_link_id(date_property_definition, "show"), /#{VALID_DATE_IN_DEFAULT_FORMAT}/)
  end

  def test_changing_project_date_format_makes_changes_throughout_project
    fake_now(2007, 12, 31)
    @browser.fake_client_timezone_offset(0)
    @card_one = create_card!(:name => 'card one')
    
    fake_now_in_new_format_for_history = "'Monday (2007/12/31)'"
    valid_date_in_new_format = '2007/10/06'
    page_name = 'foo'
    create_new_wiki_page(@project, page_name, 'stuff')
    open_card(@project, @card_one.number)
    add_new_value_to_property_on_card_show(@project, CLOSED_ON_DATE_PROPERTY, VALID_DATE_IN_DEFAULT_FORMAT)

    navigate_to_project_admin_for(@project)
    select_project_date_format(YYYY_MM_DD)
    click_save_link
    @browser.run_once_full_text_search
    @browser.run_once_history_generation
    navigate_to_history_for(@project)
    @browser.wait_for_text_present('Monday (2007/12/31)')

    open_card(@project, @card_one.number)
    load_card_history
    @browser.wait_for_text_present('Monday (2007/12/31)')

    open_wiki_page(@project, page_name)
    load_page_history
    @browser.wait_for_text_present('Monday (2007/12/31)')

    open_card(@project, @card_one.number)
    assert_properties_set_on_card_show(CLOSED_ON_DATE_PROPERTY => valid_date_in_new_format)
  ensure
    @browser.reset_fake
  end

  #bug 2623
  def test_can_change_project_date_format_when_saved_views_filter_by_date_property
    saved_view_name = 'date property not set'
    navigate_to_card_list_by_clicking(@project)
    add_new_filter
    set_the_filter_property_and_value(1, :property => CLOSED_ON_DATE_PROPERTY, :value => TODAY, :operator => 'is')
    add_new_filter
    set_the_filter_property_and_value(2, :property => OPENED_ON_DATE_PROPERTY, :value => NOT_SET, :operator => 'is')
    date_property_not_set_view = create_card_list_view_for(@project, saved_view_name)
    navigate_to_project_admin_for(@project)
    click_show_advanced_options_link
    select_project_date_format(YYYY_MM_DD)
    click_save_link
    navigate_to_card_list_by_clicking(@project)
    open_saved_view(saved_view_name)
    # Need to look at it still--- someone commented it I think by purpose 
    # assert_equal 'true', @browser.get_eval("this.browserbot.getCurrentWindow().Element.hasClassName('favorite-#{date_property_not_set_view.id}', 'selected')") 
  end
end
