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

module GroupsPage
  
  def assert_user_is_present_in_group(group_name, user)
    @browser.assert_text_present_in(GroupsPageId::GROUP_NAME_ID, group_name)
    @browser.assert_element_present(group_user_id(user))
  end
  
  def assert_back_to_group_button_present
    @browser.assert_element_present(GroupsPageId::BACK_TO_GROUP_ID)
  end

  def assert_back_to_group_list_button_present
    @browser.assert_element_present(GroupsPageId::BACK_TO_GROUP_LIST_BUTTON)
  end
  
  def assert_no_group_memember_message_present
    @browser.assert_text_present("There are currently no group members to list.")
  end
  
  def asssert_adding_group_member_from_group_page_successfull_message_present(user, group_name)
    @browser.assert_text_present("#{user.name} has been added to #{group_name}")
  end
  
  def assert_remove_from_group_button_is_disabled
    @browser.assert_has_classname(GroupsPageId::REMOVE_FROM_GROUP_ID, "disabled")
  end
  
  def assert_remove_from_group_button_is_enabled
    @browser.assert_does_not_have_classname(GroupsPageId::REMOVE_FROM_GROUP_ID, "disabled")
  end
  
  def assert_remove_from_group_button_not_present
    @browser.assert_element_not_present(GroupsPageId::REMOVE_FROM_GROUP_ID)
  end
  
  def assert_remove_multiple_users_from_group_successfull_message_present(removed_users_account, group_name)
    @browser.assert_text_present("#{removed_users_account} members have been removed from #{group_name}.")
  end

  def assert_remove_single_user_from_group_successfull_message_present(user, group_name)
    @browser.assert_text_present("#{user.name} has been removed from #{group_name}.")
  end
  
  def assert_currently_in_page(first_users_number_in_current_page, group_member_account)
    @browser.pagination-summary
  end
  
  def assert_on_the_group_member_page(project,  group, page_number)
    @browser.assert_location("/projects/#{project.identifier}/groups/#{group.id}?page=#{page_number}")
    @browser.assert_element_not_present(page_number_id(page_number))
  end
  
  def assert_dont_show_the_add_to_group_link_for_user_who_already_been_added_in_group(user)
    user_information = @browser.get_eval("this.browserbot.getCurrentWindow().$('user_#{user.id}').innerHTML.unescapeHTML()")
    expected = "Existing group member"
    assert(user_information =~ /#{expected}/im, "#{expected} expected, but response output doesn't include: #{user_information}")
  end
  
  def assert_add_group_member_button_not_present
    @browser.assert_element_not_present(GroupsPageId::ADD_GROUP_MEMBER_LINK)
  end
  
  def assert_group_name(row_number, group_name)
     assert_table_values('project_groups', row_number, 0, group_name)      
   end


   def assert_cannot_create_a_group
     @browser.assert_element_not_present(GroupsPageId::GROUP_NAME_ID)
     @browser.assert_element_not_present(GroupsPageId::SUBMIT_QUICK_ADD_ID)      
   end

   def assert_cannot_see_delete_a_group_link(project, group_name)
     group_to_be_deleted = project.user_defined_groups.find_by_name(group_name)
     click_group_name_on_group_list_page(group_name)
     assert_link_not_present("/projects/#{project.identifier}/groups/destroy/#{group_to_be_deleted.id}")      
   end  

   def assert_numbers_of_users_in_group(group_order, users_count)
     assert_equal(@browser.get_eval("this.browserbot.getCurrentWindow().$$('.numberofusers')[#{group_order}].innerHTML"), "#{users_count}")
   end

   def assert_back_to_groups_list_button_present
     @browser.assert_element_present(GroupsPageId::BACK_TO_GROUP_LIST_BUTTON)
   end

   def assert_edit_group_button_present
     @browser.assert_element_present(GroupsPageId::EDIT_GROUP_ID)
   end

   def assert_edit_group_button_not_present
     @browser.assert_element_not_present(GroupsPageId::EDIT_GROUP_ID)
   end


   def assert_back_to_team_list_button_present
     @browser.assert_element_present(GroupsPageId::BACK_TO_TEAM_LIST_BUTTON_ID)
   end
  
end
