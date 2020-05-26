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

# Tags: scenario, user
class Scenario29NonProjectMemberAccessTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_29', :users => [])
    login_as_non_project_member
    navigate_to_all_projects_page
  end

  def test_non_project_member_cannot_access_project_urls
    @browser.assert_text_present("You are currently not a member of any project.")
    assert_link_not_present("/projects/#{@project}")
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/admin/advanced"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/cards"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/cards/1"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/cards/list"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/cards/new"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/cards_import/import"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/cards_import/list/"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/wiki/Overview_Page"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/property_definitions"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/property_definitions/new"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/tags/list"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/tags/new"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/favorites/list"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/transitions/list"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/transitions/new"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/wiki/list"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/team/list"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/search?=q"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/history"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/admin/export"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/admin/export?export_as_template=true"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/projects/import"
    assert_no_accesss_error_message_when_opening "/projects/#{@project.identifier}/projects/edit/#{@project.id}"
    assert_no_accesss_error_message_when_opening "/admin/projects/new", "/projects"
    assert_no_accesss_error_message_when_opening "/projects/delete/projects/#{@project.identifier}", "/projects"
    assert_no_accesss_error_message_when_opening "/projects/confirm_delete/projects/#{@project.identifier}", "/projects"
    assert_no_accesss_error_message_when_opening "/users/list"
    assert_no_accesss_error_message_when_opening "/users/new"

    # bugs 1080 & 1131
    assert_no_accesss_error_message_when_opening "/profile/show/1"
    assert_no_accesss_error_message_when_opening "/profile/edit_profile/1"
    assert_no_accesss_error_message_when_opening "/profile/change_password/1"

  end

  def assert_no_accesss_error_message_when_opening(path, expected_redirect_url='/')
    @browser.open "#{path}"
    @browser.assert_location(expected_redirect_url)
    assert_cannot_access_resource_error_message_present
  end
end
