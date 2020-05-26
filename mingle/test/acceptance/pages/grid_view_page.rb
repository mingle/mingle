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

module GridViewPage


  def assert_grouped_by(property_name)
    @browser.assert_value(GridViewPageId::SELECT_GROUP_BY_LANE_FIELD_ID, property_name.downcase)
  end

  def assert_card_in_lane(property, value, card_number)
    id = property == 'ungrouped' ? 'ungrouped' : value
    lane = lane_htmlid(id)
    @browser.assert_element_present css_locator("##{lane} #card_#{card_number}")
  end

  def lane_htmlid(value)
    return value if value == 'ungrouped'
    "lane_#{Digest::MD5::new.update(value.to_s)}"
  end

  def row_htmlid(value)
    "row_#{Digest::MD5::new.update(value.to_s)}"
  end

  def close_popup
    @browser.click css_locator('span.x.fa.fa-times')
  end

  def lane_header_htmlid(value)
    return value if value == 'ungrouped'
    "lane_#{Digest::MD5::new.update(value.to_s)}_header"
  end

  def assert_select_all_checkbox_not_checked
    @browser.assert_not_checked GridViewPageId::SELECT_ALL_LANES_ID
  end

  def assert_select_all_checkbox_checked
    @browser.assert_checked GridViewPageId::SELECT_ALL_LANES_ID
  end


  def assert_checkbox_checked_for_lane(property,value)
    @browser.assert_checked toggle_lane_id(value)
  end

  def assert_checkbox_not_checked_for_lane(property,value)
    @browser.assert_not_checked toggle_lane_id(value)
  end

  def assert_card_description_in_card_pop_up(text)
    @browser.assert_text(card_popup_descrition_id, text)
  end

  def assert_not_card_description_in_card_pop_up(text)
    @browser.assert_text_not_present_in(card_popup_descrition_id, text)
  end

  def assert_popup_present_for_card(card)
    @browser.assert_element_present(card_popup_id(card.number))
  end

  def assert_popup_present_for_card_on_tree_view(card)
    @browser.assert_element_present("card_popup_outer_#{card.number}")
  end

  def assert_popup_not_present_for_card(card)
    @browser.assert_element_not_present(card_popup_id(card.number))
  end

  def assert_card_color(expected_color, card_number)
    card_color = @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('#card_#{card_number} .card-inner-wrapper').first().getStyle('borderLeftColor');
    })
    assert_color_equal expected_color, card_color
  end

  def assert_card_has_no_color(card_number)
    card_border =  @browser.get_eval(%{
      this.browserbot.getCurrentWindow().$$('#card_#{card_number} .card-inner-wrapper').first().getStyle('borderLeft');
    })
    # on jruby windows ie6 build, card_border is "null" when there is no border and google chrome gives 0px none rgb(51, 51, 51) for blank
    assert (card_border.blank? || card_border == "null" || card_border == "0px none rgb(51, 51, 51)"), "card #{card_number} should not have border color but it has"
  end

  def assert_cards_have_no_color(*card_numbers)
    card_numbers.each {|card_number| assert_card_has_no_color(card_number)}
  end


  def assert_card_in_lane_and_row(card, column_value, row_value)
    html_id = grid_cell_html_id(column_value, row_value)
    @browser.assert_element_present "css=##{html_id} #card_#{card.number}"
  end

  def assert_card_not_in_lane(property, value, card_number)
    id = property == 'ungrouped' ? 'ungrouped' : value
    lane = lane_htmlid(id)
    @browser.assert_element_not_present css_locator("##{lane} #card_#{card_number}")
  end

  def assert_cards_present_in_grid_view(*cards)
    cards.each {|card| @browser.assert_element_present(card_id(card))}
  end

  def assert_cards_not_present_in_grid_view(*cards)
    cards.each {|card| @browser.assert_element_not_present(card_id(card))}
  end

  def assert_lane_present(property, value)
    lane = lane_htmlid(value)
    @browser.assert_element_present "css=##{lane}"
  end

  def assert_add_column_present
    @browser.assert_element_present plus_drop_link_on_grid
  end

  def assert_lane_not_present(property, value)
    lane = lane_htmlid(value)
    @browser.assert_element_not_present "css=##{lane}"
  end

  def assert_row_not_present(value)
    @browser.assert_element_not_present "css=##{row_htmlid(value)}"
  end

  def assert_group_lane_number(expected_value, options={})
    locator = if (options[:lane])
      property = options[:lane].first
      value    = options[:lane].last.to_sym == :not_set ? '' : options[:lane].last
      "css=#group_lane_title_#{lane_htmlid(value)} .lane-card-number"
    else
      "css=.lane-card-number:eq(#{options[:lane_index] || 0})"
    end

    @browser.ruby_wait_for("group lane number to update", 5000) do
      @browser.get_text(locator).strip == "(#{expected_value})"
    end
  end

  def assert_group_row_number(expected_value, options={})
    locator = if (options[:lane])
      property = options[:lane].first
      value    = options[:lane].last.to_s == 'not_set' ? '' : options[:lane].last
      "css=#group_row_title_#{row_htmlid(value)} .row-card-number"
    else
      "css=.row-card-number:eq(#{options[:lane_index] || 0})"
    end

    @browser.ruby_wait_for("group row number to update", 5000) do
      @browser.get_text(locator).strip == "(#{expected_value})"
    end
  end

  def assert_grouped_by_not_set
    @browser.assert_value(GridViewPageId::SELECT_SORT_BY_FIELD_ID,'')
  end

  def assert_colored_by(property_name)
    @browser.assert_value(GridViewPageId::SELECT_COLOR_BY_FIELD_ID, property_name)
  end

  def assert_grid_sort_by(property_name)
    @browser.assert_value(GridViewPageId::SELECT_SORT_BY_FIELD_ID, property_name)
  end

  def assert_lane_headings(aggregation_type, aggregation_property = nil)
    @browser.assert_value(GridViewPageId::AGGREGATE_SELECT_COLUMN_ID, aggregation_type)
    unless aggregation_type.downcase == 'count'
      @browser.assert_value(GridViewPageId::AGGREGATE_PROPERTY_SELECT_FIELD_ID, aggregation_property)
    end
  end

  def assert_properties_present_on_lane_heading_drop_down_list(*properties)
    @browser.click(aggregate_property_drop_link_id)
    properties.each{|property| assert_property_present_in_aggregate_property(property)}
    @browser.click(aggregate_property_drop_link_id)
  end

  def assert_property_present_in_aggregate_property(property)
    droplist_option_id = aggregate_property_option_id(property)
    @browser.assert_element_present(droplist_option_id)
    @browser.assert_element_text(droplist_option_id, property)
  end

  #Methods for Group columns by:
  def assert_properties_present_on_group_columns_by_drop_down_list(*properties)
    @browser.click(group_by_columns_drop_link_id)
    @browser.wait_for_element_present(css_locator("##{group_by_columns_drop_down} ul li"))
    properties.each{|property| assert_property_present_in_group_columns_by(property)}
    @browser.click(group_by_columns_drop_link_id)
  end

  def assert_properties_not_present_on_group_columns_by_drop_down_list(*properties)
    @browser.click(group_by_columns_drop_link_id)
    @browser.wait_for_element_present(css_locator("##{group_by_columns_drop_down} ul li"))
    properties.each{|property| assert_property_not_present_in_group_columns_by(property)}
    @browser.click(group_by_columns_drop_link_id)
  end

  def assert_property_present_in_group_columns_by(property)
    droplist_option_id = group_by_columns_option_id(property)
    @browser.assert_element_present(droplist_option_id)
    @browser.assert_element_text(droplist_option_id, property)
  end

  def assert_property_not_present_in_group_columns_by(property)
    droplist_option_id = group_by_columns_option_id(property)
    @browser.assert_element_not_present(droplist_option_id)
  end

  #Methods for Group by rows by:
  def assert_properties_present_on_group_rows_by_drop_down_list(*properties)
    @browser.click(group_by_rows_drop_link_id)
    @browser.wait_for_element_present(css_locator("##{group_by_rows_drop_down} ul li"))
    properties.each{|property| assert_property_present_in_group_rows_by(property)}
    @browser.click(group_by_rows_drop_link_id)
  end

  def assert_properties_not_present_on_group_rows_by_drop_down_list(*properties)
    @browser.click(group_by_rows_drop_link_id)
    @browser.wait_for_element_present(css_locator("##{group_by_rows_drop_down} ul li"))
    properties.each{|property| assert_property_not_present_in_group_rows_by(property)}
    @browser.click(group_by_rows_drop_link_id)
  end

  def assert_property_present_in_group_rows_by(property)
    droplist_option_id = group_by_rows_option_id(property)
    @browser.assert_element_present(droplist_option_id)
    @browser.assert_element_text(droplist_option_id, property)
  end

  def assert_property_not_present_in_group_rows_by(property)
    droplist_option_id = group_by_rows_option_id(property)
    @browser.assert_element_not_present(droplist_option_id)
  end

  def assert_properties_present_on_color_by_drop_down_list(*properties)
    properties.each{|property| assert_property_present_in_color_by(property)}
  end

  def assert_properties_not_present_on_color_by_drop_down_list(*properties)
    properties.each { |property| assert_property_not_present_in_color_by(property) }
  end

  def assert_property_not_present_in_color_by(property)
    @browser.click(color_by_drop_link_id)
    droplist_option_id = color_by_option_id(property)
    @browser.assert_element_not_present(droplist_option_id)
    @browser.click(color_by_drop_link_id)
  end

  def assert_property_present_in_color_by(property)
    @browser.click(color_by_drop_link_id)
    droplist_option_id = color_by_option_id(property)
    @browser.wait_for_element_present droplist_option_id
    # @browser.assert_element_present(droplist_option_id)
    @browser.click(color_by_drop_link_id)
  end

  def assert_properties_present_on_sort_by_drop_down_list(*properties)
    @browser.click(sort_by_drop_link_id)
    properties.each{|property| assert_property_present_in_sort_by(property)}
    @browser.click(sort_by_drop_link_id)
  end

  def assert_properties_not_present_on_sort_by_drop_down_list(*properties)
    @browser.click(sort_by_drop_link_id)
    properties.each { |property| assert_property_not_present_in_sort_by(property) }
    @browser.click(sort_by_drop_link_id)
  end

  def assert_property_present_in_sort_by(property)
    droplist_option_id = sort_by_option_id(property)
    @browser.assert_element_present(droplist_option_id)
    @browser.assert_element_text(droplist_option_id, property)
  end

  def assert_property_not_present_in_sort_by(property)
    @browser.click(sort_by_drop_link_id)
    droplist_option_id = sort_by_option_id(property)
    @browser.assert_element_not_present(droplist_option_id)
  end

  def assert_properties_in_group_by_are_ordered(*properties)
    @browser.click(group_by_columns_drop_link_id)
    properties.each_with_index do |property, index|
      assert_ordered(group_by_columns_option_id(property), group_by_columns_option_id(properties[index + 1])) unless property == properties.last
    end
    @browser.click(group_by_columns_drop_link_id)
  end

  def assert_properties_in_color_by_are_ordered(*properties)
    @browser.click(color_by_drop_link_id)
    properties.each_with_index do |property, index|
      assert_ordered(color_by_option_id(property), color_by_option_id(properties[index + 1])) unless property == properties.last
    end
    @browser.click(color_by_drop_link_id)
  end

  def assert_properties_in_lane_headings_are_ordered(*properties)
    @browser.click(aggregate_property_drop_link_id)
    properties.each_with_index do |property, index|
      assert_ordered(aggregate_property_option_id(property), aggregate_property_option_id(properties[index + 1])) unless property == properties.last
    end
    @browser.click(aggregate_property_drop_link_id)
  end

  def assert_grid_rows_ordered(*row_headings)
    row_headings.each_with_index do |heading, index|
      assert_match /#{heading}/, @browser.get_text("css=tbody .row_header:eq(#{index})")
    end
  end

  def assert_order_of_lanes_in_grid_view(*lane_headings)
    lane_headings.each_with_index do |heading, index|
      assert_match heading, @browser.get_text(class_locator('lane_header', index))
    end
  end

  def assert_order_of_add_lane_dropdown(*lane_names)
    lane_names.each_with_index do |lane_name, index|
      assert_match lane_name, @browser.get_text(class_locator('ui-menu-item', index))
    end
  end

  def assert_properties_order_in_grid_view_card_popup(card_number, *properties)
    @browser.click(card_on_grid_view_id(card_number))
    if @browser.is_element_present(card_popup_id(card_number))
      index = 0
      properties.each do |property, value|
        properties_actual = @browser.get_eval("this.browserbot.getCurrentWindow().$('card_show_lightbox_content').select('.property-in-popup')[#{index}].innerHTML.unescapeHTML();")
        assert_equal("#{property}:#{value.to_s}", properties_actual.strip_all)
        index = index + 1
      end
    else
      raise "error"
    end
  end

  def assert_color_legend_contains_type(card_type)
    @browser.assert_element_present color_legend_for_card_type_id(card_type)
  end

  def assert_color_legend_does_not_contain_type(card_type)
    @browser.assert_element_not_present color_legend_for_card_type_id(card_type)
  end

  def assert_color_legend_displayed
    @browser.assert_visible(GridViewPageId::COLOR_LEGEND_ID)
  end

  def assert_color_legend_not_displayed
    @browser.assert_text_not_present(GridViewPageId::COLOR_LEGEND_ID)
  end

  def assert_color_leged_popup_not_present_for(project, property, value)
    project = project.identifier if project.respond_to? :identifier
    value = Project.find_by_identifier(project).find_enumeration_value(property, value, :with_hidden => true)
    @browser.assert_element_not_present(color_popup_on_grid_view_id(value))
  end

  def assert_grid_view_actions_bar_present
    @browser.assert_element_present(group_by_columns_drop_link_id)
    @browser.assert_element_present(sort_by_drop_link_id)
    @browser.assert_element_present(color_by_drop_link_id)
    @browser.assert_element_present(aggregate_type_drop_link_id)
    @browser.assert_element_present(aggregate_property_drop_link_id)
  end

  def assert_property_on_popup(expected_property_and_value, card_number, property_index)
    properties_actual = @browser.get_eval("this.browserbot.getCurrentWindow().$('card_show_lightbox_content').select('.property-definition')[#{property_index}].innerHTML.unescapeHTML();")
    assert_equal(expected_property_and_value.strip_all, properties_actual.strip_all)
  end

  def assert_property_on_popup_on_tree_view(expected_property_and_value, card_number, property_index)
    properties_actual = @browser.get_eval("this.browserbot.getCurrentWindow().$('card_popup_outer_#{card_number}').select('.property-in-popup')[#{property_index}].innerHTML.unescapeHTML();")
    assert_equal(expected_property_and_value.strip_all, properties_actual.strip_all)
  end


  def assert_ranking_option_button_is_not_present
    @browser.assert_element_not_present(GridViewPageId::RANK_CHECKBOX)
    @browser.assert_element_not_present("css=.rank-checkbox-label")
  end

  def assert_ranking_option_button_is_present
    @browser.assert_element_present(GridViewPageId::RANK_CHECKBOX)
    @browser.assert_element_present("css=.rank-checkbox-label")
  end

  def assert_ranking_mode_is_turn_off
    @browser.assert_not_checked(GridViewPageId::RANK_CHECKBOX)
    @browser.assert_element_present("css=.rank_is_off")
  end

  def assert_ranking_mode_is_turn_on
    @browser.assert_checked(GridViewPageId::RANK_CHECKBOX)
    @browser.assert_element_present("css=.rank_is_on")
  end

  def assert_rank_is_selected_in_sort_by
    rank = ''
    @browser.assert_value(GridViewPageId::SELECT_SORT_BY_FIELD_ID, rank)
  end

  def assert_show_hide_grid_settings_button_is_not_present
    @browser.assert_not_visible(GridViewPageId::GRID_SETTING_TOGGLE)
  end

  def assert_transition_ordered_in_card_popup(*transitions)
    assert_ordered(transitions.collect {|transition| transition_on_grid_view_id(transition)})
  end

  def assert_transition_ordered_in_transitions_popup(*transitions)
    assert_ordered(transitions.collect {|transition| transition_on_grid_view_id(transition)})
  end

  def assert_tooltip_for_mini_card_link_present
    @browser.assert_element_present("css=a[title='Click to go directly to this card']")
  end

  def assert_maximise_view_link_present
     @browser.assert_visible(GridViewPageId::MAXIMIZE_VIEW_ID)
   end

   def assert_maximise_view_link_not_present
     @browser.assert_not_visible(GridViewPageId::MAXIMIZE_VIEW_ID)
   end

   def assert_restore_view_link_present_on_the_action_bar
     @browser.assert_visible(css_locator("a.restore-view"))
   end

   def assert_transition_only_error_message_on_grid(message)
     @browser.wait_for_element_present(GridViewPageId::TRANSITION_TOOL_TIP)
     @browser.assert_element_matches(GridViewPageId::TRANSITION_TOOL_TIP, /#{message}/)
   end

   def assert_link_present_on_mini_card(card)
     @browser.assert_element_present(card_show_link_id(card))
   end

   def assert_draggable_lanes_present
    @browser.assert_element_present(GridViewPageId::DRAGGABLE_LANES)
   end

   def assert_draggable_lanes_not_present
    @browser.assert_element_not_present(GridViewPageId::DRAGGABLE_LANES)
   end
end
