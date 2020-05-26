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

module GroupsAction

    def navigate_to_group_list_page(project)
        @browser.open "/projects/#{project.identifier}/groups"
    end

    def open_group(project, group_name)
        navigate_to_group_list_page(project)
        click_group_name_on_group_list_page(group_name)
    end

    def open_group_from_url(project, group)
        @browser.open "/projects/#{project.identifier}/groups/#{group.id}"
    end

    def click_add_group_member_button
        @browser.click_and_wait GroupsPageId::ADD_USER_AS_MEMBER_LINK
    end


    def click_add_to_group_link(user)
        @browser.with_ajax_wait do
            @browser.click add_user_to_group_id(user)
        end
    end

    def click_remove_from_group_button
        @browser.click_and_wait(GroupsPageId::REMOVE_FROM_GROUP_ID)
    end

    def click_back_to_group_button
        @browser.click_and_wait(GroupsPageId::BACK_TO_GROUP_ID)
    end

    def click_next_page_link
        @browser.click_and_wait(next_page_id)  
    end

    def create_a_group_for_project(project, group_name)
        navigate_to_group_list_page(project)
        create_a_group(group_name)
        @project.user_defined_groups.find_by_name(group_name)
    end

    def create_a_group(group_name)
        @browser.type(GroupsPageId::GROUP_NAME_ID, group_name)
        @browser.click_and_wait(GroupsPageId::SUBMIT_QUICK_ADD_ID)      
    end

    def click_group_name_on_group_list_page(group_name)
        @browser.click_and_wait(group_name_link(group_name))
    end

    def delete_group(project, group_name)
        group_to_be_deleted = project.user_defined_groups.find_by_name(group_name)
        @browser.click_and_wait delete_group_id(group_to_be_deleted)
    end 

    def change_group_name_to(new_group_name) 
        @browser.click(GroupsPageId::EDIT_GROUP_ID) 
        @browser.type(GroupsPageId::GROUP_NAME_EDITOR_ID, new_group_name)
        @browser.with_ajax_wait { @browser.click(GroupsPageId::SAVE_GROUP_ID) }
    end

    def create_group_and_add_its_members(group_name, members=[])
        perform_as('admin@email.com') do
            group = Project.current.groups.create!(:name => group_name)
            members.each { |member| group.add_member(member) }
            group
        end 
    end

    def delete_group_with_confirmation(project, group_name)
        delete_group(project, group_name)
        @browser.click_and_wait GroupsPageId::CONFIRM_BUTTON_ID 
    end

    def cancel_edit
        @browser.click(GroupsPageId::CANCEL_GROUP_ID)
    end

    def click_back_to_groups_list_button
        @browser.click_and_wait(GroupsPageId::BACK_TO_GROUP_LIST_BUTTON)
    end

    def click_back_to_team_list_button
        @browser.click_and_wait(GroupsPageId::BACK_TO_TEAM_LIST_BUTTON_ID)
    end
end
