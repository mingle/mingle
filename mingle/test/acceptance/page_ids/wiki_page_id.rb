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

module WikiPageId

  TABLE_IDENTIFIER = 'content'
  PROJECT_IDENTIFIER_ID="project_identifier"
  INSERT_MACRO_BUTTON_ID='submit_macro_editor'
  MACRO_TYPE_DROPDOWN_ID= 'macro_type'
  PREVIEW_MACRO_BUTTON_ID= "link=Preview"
  MACRO_PREVIEW_CONTENT_ID="macro_preview"
  CHART_DATA_LINK = 'Chart Data'
  PREVIEW_TAB_LINK_ID="link=Preview"
  SAVE_BUTTON_ID="//input[@class='save']"
  CARD_DESCRIPTION_ID='card_description'
  EDIT_PAGE_CONTENT_ID='page_content'
  VIEW_PAGE_CONTENT_ID='page-content'
  SAVE_LINK_ON_WIKI='link=Save'
  MAKE_TEAM_FAVORITE_ID = 'Make team favorite'
  MAKE_TAB_ID = 'Make tab'
  EDIT_WIKI_PAGE_LINK='link=Edit'
  BACK_WIKI_PAGE_LINK='link=go back'
  LATEST_VERSION_WIKI_PAGE_LINK='link=latest version'
  WHY_NOT_CREATE_WIKI_PAGE_LINK='link=why not create it...'
  EXPAND_HISTORY_ID='history_collapsible_expand_header'
  HISTORY_SPINNER_ID='history_collapsible_spinner'
  REMOVE_TAB_LINK='top_tab_link'
  MAKE_TEAM_FAVORITE_LINK='top_favorite_link'
  PREVIEW_PANEL_CONTAINER_ID="preview_panel_container"
  WARNING_OF_VIEWING_OLD_WIKI_CONTENT = "This page has changed since you opened it for viewing. The latest version was opened for editing. You can continue to edit this content, go back to the previous page or view the latest version."

  def header_name_link(header_name)
    "link=+#{header_name}"
  end

  def page_number_link(page_number)
    "page_#{page_number}"
  end

  def html_name_for_macro(name,param)
    "macro_editor[#{name}][#{param}]"
  end

  def html_id_for_macro(name,param)
    "macro_editor_#{name}_#{param}"
  end

  def macro_button_id(macro_name)
    "#{macro_name}-macro-button"
  end

  def macro_name_panel(macro_name)
    "#{macro_name}_macro_panel"
  end

  def macro_editor_series_level_parameter_id(macro_name,series_index,para)
    "macro_editor[#{macro_name}][series][#{series_index}][#{para}]"
  end

  def macro_editor_popup
    "css=.cke_dialog_ui_vbox_child"
  end

  def optional_parameter_chart_option_id(chart_type,parameter)
    "#{chart_type}_optional_parameter_option_#{parameter.to_s}"
  end

  def add_optional_parameter_droplink(chart_type)
    "#{chart_type}_optional_parameter_drop_link"
  end

  def remove_optional_parameter_id(macro_type,para)
    parameter_id = "#{macro_type}_#{para.to_s}_parameter"
    return "css=##{parameter_id} a.remove-optional-parameter"
  end

  def remove_chart_series_optional_parameter_id(chart_type,chart_series,para)
    parameter_id = "#{chart_type}_series_#{chart_series}_#{para.to_s}_parameter_container"
    return "css=##{parameter_id} a.remove-optional-parameter"
  end

  def series_level_optional_parameter_chart_option_id(chart_type,series_index,parameter)
    "#{chart_type}_series_#{series_index}_optional_parameter_option_#{parameter.to_s}"
  end

  def series_level_add_optional_parameter_droplink(chart_type,index)
    "#{chart_type}_series_#{index}_optional_parameter_drop_link"
  end

  def remove_series_id(chart_type,index)
    "#{chart_type}_remove_series_button_#{index}"
  end

  def add_series_id(chart_type,index)
    "#{chart_type}_add_series_button_#{index}"
  end

  def series_container_id(chart_type,options)
    "#{chart_type}_series-container-#{options[:expected_series_index_added]}"
  end

  def series_container_index_id(chart_type,index)
    "#{chart_type}_series-container-#{index}"
  end

  def series_parameter_container_id(chart_type,chart_series,para)
    "#{chart_type}_series_#{chart_series}_#{para.to_s}_parameter_container"
  end

  def macro_name_parameter_id(macro_name,index,para)
    "#{macro_name}_series_#{index}_#{para.to_s}_parameter_container"
  end

  def remove_chart_macro_series_level_id(parameter_id)
    "css=##{parameter_id} a.remove-optional-parameter"
  end

  def wiki_page_color_popup_id(chart_type,chart_series,para)
    "css=##{chart_type}_series_#{chart_series}_#{para}_parameter_container .color_block"
  end

  def ok_button_in_color_popup_id(chart_type,series_index,parameter_name)
    "css=##{chart_type}_series_#{series_index}_#{parameter_name}_parameter_container input[type=button][value=OK]"
  end

  def remove_from_favorite_link
    "css=#top_favorite_link[title='Remove team favorite']"
  end

  def macro_name_parameters_visibility(macro_name,para)
    "#{macro_name}_#{para.to_s}_parameter"
  end

  def wiki_link_not_present
    "css=a.non-existent-wiki-page-link"
  end

  def wiki_favorite_present(wiki_favorite)
    "css=.wiki-favorite a:contains(#{wiki_favorite})"
  end

end
