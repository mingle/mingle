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

module GridViewPageId
  GRID_VIEW_LINK='link=Grid'
  MAXIMIZE_VIEW_ID="css=a.maximize-view"
  RESTORE_VIEW_ID="css=a.restore-view"
  ADD_REMOVE_COLUMNS_LINK="link=Add / remove columns"
  SELECT_PROPERTY_LINK='(select property...)'
  APPLY_SELECTED_LANES_ID="apply_selected_lanes"
  SELECT_ALL_LANES_ID="select_all_lanes"
  AGGREGATE_PROPERTY_SELECT_FIELD_ID='select_aggregate_property_column_field'
  RANK_CHECKBOX="rank_checkbox"
  GRID_SETTING_TOGGLE ="grid_settings_toggle"
  TRANSITION_TOOL_TIP='transition_only_tooltip'
  SELECT_SORT_BY_FIELD_ID='select_sort_by_field'
  COLOR_LEGEND_ID='color-legend'
  AGGREGATE_SELECT_COLUMN_ID='select_aggregate_type_column_field'
  SELECT_COLOR_BY_FIELD_ID='select_color_by_field'
  CARD_POPUP_DESCRIPTION_ID='card-popup-description'
  SELECT_GROUP_BY_LANE_FIELD_ID='select_group_by_lane_field'
  DRAGGABLE_LANES="xpath=//th[@class='lane_header draggable_lane']"
  CARD_TYPES_DROP_LINK_ID = 'card_type_name_drop_link'
  TRANSITIONS_BUTTON = "card-transitions-button"

  def restore_view_id
    css_locator("a.restore-view")
  end

  def card_popup_descrition_id
    css_locator(".card-popup-lightbox #card-description .wiki")
  end

  def toggle_lane_id(value)
    "toggle_lane_#{lane_htmlid(value)}"

  end

  def card_on_grid_view_id(card_number)
    "card_inner_wrapper_#{card_number}"
  end

  def transition_on_grid_view_id(transition)
    "transition_#{transition.id}"
  end

  def card_id(card)
    "card_#{card.number}"
  end

  def grid_transition_link(transition)
    "link=#{transition.name}"
  end

  def card_show_link_id(card)
    "card_show_link_#{card.number}"

  end

  def sort_by_drop_link_id
    "select_sort_by_drop_link"
  end

  def sort_by_option_id(property_name)
    "select_sort_by_option_#{property_name}"
  end

  def group_by_rows_drop_link_id
    "select_group_by_row_drop_link"
  end

  def group_by_rows_option_id(property_name)
    "select_group_by_row_option_#{property_name}"
  end

  def group_by_rows_drop_down
    "select_group_by_row_drop_down"
  end

  def grid_view_row_header_id(row_heading)
    row_heading_with_space = " "+ row_heading +" "
    "css=th:contains(#{row_heading_with_space})"
      #"xpath=//th[contains(text(), ' #{row_heading} ')][0]"
  end

  def color_by_option_id(property_name)
    "select_color_by_option_#{property_name}"
  end

  def color_by_drop_link_id
    "select_color_by_drop_link"
  end

  def aggregate_type_drop_link_id
    'select_aggregate_type_column_drop_link'
  end

  def aggregate_type_option_id(property_name)
    "select_aggregate_type_column_field_option_#{property_name}"
  end

  def aggregate_property_drop_link_id
    "select_aggregate_property_column_drop_link"
  end

  def aggregate_property_option_id(property_name)
    "select_aggregate_property_column_field_option_#{property_name}"
  end

  def group_by_columns_drop_link_id
    "select_group_by_lane_drop_link"
  end

  def group_by_columns_option_id(property_name)
    "select_group_by_lane_option_#{property_name}"
  end

  def group_by_columns_drop_down
    "select_group_by_lane_drop_down"
  end

  def row_htmlid(value)
    "row_#{Digest::MD5::new.update(value.to_s)}"
  end

  def grid_cell_html_id(column_value, row_value)
    #see group_lanes.rb html_id method to understand how the row/column html identifiers are created and why we do this.
    "lane_#{Digest::MD5::new.update(column_value.to_s)}_row_#{Digest::MD5::new.update(row_value.to_s)}"
  end

  def color_popup_on_grid_view_id(value)
    "color_popup_#{value.id}"
  end

  def color_legend_for_card_type_id(card_type)
    "color-legend-type-#{card_type}"
  end

  def card_popup_id(card_number)
    "card_show_lightbox_content"
  end

  def lane_id(prop_value)
    "css=#group_lane_title_#{lane_htmlid(prop_value)} > div.editable_lane.header-title"
  end

  def card_type_name_option_id(value)
    "card_type_name_option_#{value}"
  end
end
