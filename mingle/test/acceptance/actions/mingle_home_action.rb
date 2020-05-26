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



module MingleHomeAction

    def navigate_to_all_projects_page(force = false)
        @browser.open('/projects') if force || !@browser.is_element_present(MingleHomePageId::PROJECT_LIST_ID)
    end

    def navigate_to_programs_page
      @browser.open('/programs')
    end

    def open_mingle_admin_dropdown
      @browser.click(MingleHomePageId::ADMIN_DROPDOWN_LINK)
    end

    def click_all_projects_link
        @browser.click_and_wait(MingleHomePageId::ALL_PROJECTS_LINK)
    end

    def click_project_link_in_header(project)
        @browser.click_and_wait(project_link_on_mingle_home(project))
    end

    def request_membership
        @browser.click_and_wait MingleHomePageId::REQUEST_MEMBERSHIP_LINK
    end

    def click_new_project_link
        @browser.click_and_wait(MingleHomePageId::NEW_PROJECT_LINK)
    end


    def create_template_for(project)
        project = project.identifier if project.respond_to? :identifier
        navigate_to_all_projects_page
        @browser.with_ajax_wait do
            @browser.click(create_template_for_project(project))
        end
    end

    #prefix of project name should be restricted to no more than 11 letters
    # otherwise, it will be cut off in project.identifier, then we cannot get the correct template identifier
    def create_template_and_activate_it(project)
        create_template_for(project)
        template_identifier = "#{project.identifier}_template"
        project_template = Project.find_by_identifier("#{@project.identifier}_template")
        project_template.activate
        project_template
    end

    def click_user_on_project_delete_warning_page(login_name)
        @browser.click_and_wait(login_name_on_warning_link(login_name))
    end

    def delete_project_permanently(project)
        delete_project project.identifier
        @browser.click MingleHomePageId::CONTINUE_TO_DELETE_LINK
        @browser.wait_for_element_present("css=input[name=\"projectName\"]")
        @browser.type("css=input[name=\"projectName\"]", project.name)
        @browser.click_and_wait "css=.confirm-me input[type=\"submit\"]"
    end

    def delete_project(project)
        project = project.identifier if project.respond_to? :identifier
        navigate_to_all_projects_page
        @browser.click_and_wait delete_project_link(project)
    end

    def navigate_to_about_mingle_page
        @browser.open('/projects/mingle/about')
      end

      def click_about_link
        @browser.click_and_wait(MingleHomePageId::ABOUT_LINK)
      end

end
