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

module ProjectHomePageId

  RESET_TO_DEFAULT_TAB='reset_to_tab_default'
  QUICK_ADD_MORE_DETAIL_ID='quick-add-more-detail'
  ADD_CARD_LINK="add_card_with_defaults"
  HISTORY_LINK='link=History'
  CARD_TYPE_NAME_DROPDOWN="card_card_type_name"
  QUICK_ADD_CARD_NAME='card[name]'
  QUICK_ADD_BUTTON_ID="quick_add_button"
  EDIT_CARD_COMMENT_ID='edit-card-comment'
  DISMISS_LIGHTBOX_BUTTON_ID="dismiss_lightbox_button"
  ALL_TAB_ID='tab_all'
  MAGIC_CARD_THUMBNAIL="magic_card_thumbnail"
  QUICK_CARD_CARD_ID='add_card_with_defaults'
  MAGIC_CARD_ID="magic_card"

  def open_card_link()
    "css=div#notice a"
  end

  def search_button
    'search_button'
  end

  def search_text_box
    'q'
  end


  def tab_id(tab_name)
    "tab_#{tab_name.downcase.gsub(/[^a-z0-9]/, '_')}"
  end

  def tab_link_id(tab_name)
    tab_id(tab_name) + "_link"
  end

end
