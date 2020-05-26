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

module GroupsPageId
  
  ADD_USER_AS_MEMBER_LINK ="link=Add user as member"
  REMOVE_FROM_GROUP_ID="remove_from_group"
  BACK_TO_GROUP_ID = "link=Back to group"
  BACK_TO_GROUP_LIST_BUTTON = "back_to_group_list_button"
  BACK_TO_TEAM_LIST_BUTTON_ID = "back_to_team_list_button"
  GROUP_NAME_ID ='group_name'
  EDIT_GROUP_ID ="edit-group"
  SAVE_GROUP_ID = "save-group"
  CANCEL_GROUP_ID = "cancel-group"
  SUBMIT_QUICK_ADD_ID ='submit-quick-add'
  GROUP_NAME_EDITOR_ID = "group_name_editor"
  CONFIRM_BUTTON_ID ="confirm_bottom"
  ADD_GROUP_MEMBER_LINK="link=Add group member"
  
  
  
  def add_user_to_group_id(user)
    "add-user_#{user.id}-to-group"
  end
  
  def next_page_id
    class_locator("next_page", 0)
  end
  
  def group_name_link(group_name)
    "link=#{group_name}"
  end
  
  def delete_group_id(group_to_be_deleted)
    "delete_group_#{group_to_be_deleted.id}"
  end
  
  def group_user_id(user)
    "user_#{user.id}"
  end
  
  def page_number_id(page_number)
  "page_#{page_number}"
  end
  
end
