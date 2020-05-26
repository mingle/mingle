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

#Tags: scenario, import-export, cards, project
class Scenario148ProjectImportAndExportTest < ActiveSupport::TestCase
  
  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)  
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_148', :admins => [users(:proj_admin)], :users => [users(:project_member)])    
  end

  #story 3707
  def test_provide_cancel_button_when_try_to_export_project
    login_as_proj_admin_user
    go_to_export_project_page(@project)
    @browser.assert_text_present("Are you sure you want to export this project? This could take a very long time for large projects.")
    assert_continue_to_export_and_cancel_links_present
    should_be_able_to_cancel_the_export_process
  end

  def test_provide_cancel_button_when_try_to_export_project_as_template
    login_as_proj_admin_user
     go_to_export_project_as_template_page(@project)
    @browser.assert_text_present("Are you sure you want to export this project as a template? This could take a very long time for large projects.")
    assert_continue_to_export_and_cancel_links_present
    should_be_able_to_cancel_the_export_process
  end

  #bug #8029
  def test_provide_cancel_button_when_full_member_try_to_export_project
    login_as_project_member
    go_to_export_project_page(@project)
    @browser.assert_text_present("Are you sure you want to export this project? This could take a very long time for large projects.")
    assert_continue_to_export_and_cancel_links_present
    full_member_should_be_able_to_cancel_the_export_process

     go_to_export_project_as_template_page(@project)
      @browser.assert_text_present("Are you sure you want to export this project as a template? This could take a very long time for large projects.")
      assert_continue_to_export_and_cancel_links_present
    full_member_should_be_able_to_cancel_the_export_process
  end

  # Story 12754 -quick add on funky tray
  def test_should_be_able_to_quick_add_card_on_porject_admin_pages
    login_as_project_member
    go_to_export_project_page(@project)
    assert_quick_add_link_present_on_funky_tray
    add_card_via_quick_add("new card")
    @browser.wait_for_element_visible("notice")
    card = find_card_by_name("new card")
    assert_notice_message("Card ##{card.number} was successfully created.", :escape => true)
  end

end
