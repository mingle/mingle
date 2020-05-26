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

module ManageUsersAction

    def navigate_to_user_management_page
        @browser.open("/users/list")
    end

    def navigate_to_delete_users_page
        @browser.open("/users/deletable")
    end

    def type_search_user_text(text)
        @browser.type(ManageUsersPageId::SEARCH_USER_TEXT_BOX, text)
    end

    def click_search_user_button
        @browser.click_and_wait(ManageUsersPageId::SEARCH_USER_SUBMIT_BUTTON)
    end

    def click_clear_search_user_button
        @browser.click_and_wait(ManageUsersPageId::SEARCH_ALL_USERS)
    end

    def click_search_button
        @browser.click_and_wait(ManageUsersPageId::SEARCH_BUTTON)
    end

    def search_user_in_user_management_page(text_to_search)
        show_all_users
        type_search_user_text(text_to_search)
        click_search_user_button
    end

    def show_all_users
        if @browser.is_element_present(ManageUsersPageId::SEARCH_ALL_USERS)
            @browser.click_and_wait(ManageUsersPageId::SEARCH_ALL_USERS)
        end
    end

    def find_user_by_name(full_name)
        User.find_by_name("#{full_name}")
    end

    def assign_project_to_the_user
      @browser.get_eval("this.browserbot.getCurrentWindow().$('#{SharedFeatureHelperPageId::ASSIGN_PROJECT_SUBMIT_ID}').click()")
      @browser.wait_for_page_to_load
    end

    def click_add_to_projects_button
        @browser.with_ajax_wait {@browser.click(ManageUsersPageId::ADD_USERS_TO_PROJECTS)}
        @browser.wait_for_condition(%{
            selenium.browserbot.getCurrentWindow().ProjectAssignment.initialized;
            }, 120000)
        end


    def select_project_from_droplist(droplist_number, project, open=true)
      if open
        open_select_project_droplist(droplist_number)
      end
      @browser.click(select_project_option(droplist_number,project))
    end

        def select_membership_type_from_droplist(droplist_number, membership_type)
            open_select_membership_droplist(droplist_number)
            @browser.click(select_permission_option(droplist_number,membership_type))
        end

        def click_add_another_project_button
          begin
            @browser.click(ManageUsersPageId::ADD_NEW_PROJECT_ASSIGNMENT)
          end while (@browser.get_eval("selenium.browserbot.getCurrentWindow().$$('.drop-list-panel')[0] != null") == 'false')

        end

        def open_select_project_droplist(droplist_number)
            @browser.click(select_project_drop_link(droplist_number))
        end

        def open_select_membership_droplist(droplist_number)
            @browser.click(select_permission_drop_link(droplist_number))
        end


        def close_select_project_droplist(droplist_number)
            @browser.click(select_project_drop_link(droplist_number))
        end

    end
