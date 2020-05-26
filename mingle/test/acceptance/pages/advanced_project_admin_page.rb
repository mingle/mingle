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

module AdvancedProjectAdminPage

  def assert_health_check_successful_message_present
    @browser.assert_text_present("We have not identified any issues with your project data or structure. Please continue to work as normal.")
  end

  def assert_advanced_project_admin_link_is_present(project)
    @browser.assert_element_present(AdvancedProjectAdminPageId::ADVANCED_PROJECT_ADMIN_LINK)
    @browser.click_and_wait(AdvancedProjectAdminPageId::ADVANCED_PROJECT_ADMIN_LINK)
    @browser.assert_location("/projects/#{project.identifier}/admin/advanced")
    @browser.assert_text_present("Advanced project administration")
  end

  def assert_advanced_project_admin_link_is_not_present
    @browser.assert_element_not_present(AdvancedProjectAdminPageId::ADVANCED_PROJECT_ADMIN_LINK)
  end

end
