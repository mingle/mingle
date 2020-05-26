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

module CardEditPageId

  CARD_DESCRIPTION='card_description'
  CARD_COMMENT_ID_ON_EDIT = 'pseudo-card-comment'
  MURMUR_THIS_COMMENT_CHECKBOX ="murmur-this-edit"
  EDIT_PROPERTIES_CONTAINER='edit-properties-container'
  COMMENT_TAB_ID = 'discussion-link'
  CARD_NAME='card_name'
  CANCEL_LINK_ID = 'link=Cancel'
  RENDERABLE_CONTENTS ='renderable-contents'
  UPLOAD_IMAGE_FIELD="name=upload"
  INSERT_IMAGE_TOOL_ID = "css=a[title='Insert image']"

  def table_present_in_wysiwyg_editor
    "css=.wiki table"
  end

  def image_present_in_wysiwyg_editor(macro_name)
    "css=img[alt='#{macro_name}']"
  end
  def save_card_button
    "css=.save-button"
  end

  def show_latest_link
    'link=Show latest'
  end

  def save_and_add_another_button
    "css=a.add"
  end

  def edit_property_search_hightlighted_id(property, value)
    "css=##{droplist_option_id(property, value, 'edit')} strong"
  end

  def c3_data_label(label)
    "css=.c3 .c3-legend-item-#{label}"
  end
end
