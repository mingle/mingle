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

module TagMgmtAndUsagePageId

  TAG_NAME_ID='tag_name'
  CREATE_TAG_LINK="link=Create tag"
  SAVE_TAG_LINK="link=Save tag"
  CONTINUE_TO_DELETE='link=Continue to delete'
  TAG_LIST_ID='tag_list'
  TAGGED_WITH_ID='tagged_with'
  FILTER_TAGS_ID='filter_tags'
  TAGS_ID='tags'
  TAG_LIST_TAG_EDITOR_CONTAINER ="tag_list-tags-editor-container"
  BULK_TAGGING_PANEL='bulk-tagging-panel'

  def edit_tag(tag)
    "edit-#{tag.html_id}"
  end

  def delete_tag(tag)
    "destroy-#{tag.html_id}"
  end

  def delete_tag_id(tag)
    "delete-#{tag.to_s.gsub(/\W/, '-')}"
  end

  def add_available_tag(tag)
    "addAvailableTag('#{tag}')"
  end

end
