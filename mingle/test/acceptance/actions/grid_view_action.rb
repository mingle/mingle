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

module GridViewAction

  def switch_to_grid_view
    @browser.click_and_wait GridViewPageId::GRID_VIEW_LINK
    @browser.wait_for_element_visible "ranking_control" unless @browser.is_element_present 'info'
  end

  def navigate_to_grid_view_for(project, options={})
    project = project.identifier if project.respond_to? :identifier
    url = "/projects/#{project}/cards/grid"
    url += '?' + options.collect { |name, value| "#{name}=#{value.gsub(/ /, '+')}" }.join('&') if options.any?
    @browser.open url
    @browser.wait_for_all_ajax_finished
  end

  def maximize_current_view
    if @browser.is_visible(GridViewPageId::MAXIMIZE_VIEW_ID)
      @browser.click_and_wait(GridViewPageId::MAXIMIZE_VIEW_ID)
      @browser.wait_for_element_visible(GridViewPageId::RESTORE_VIEW_ID)
    end
  end

  def restore_current_view
    if @browser.is_visible(GridViewPageId::RESTORE_VIEW_ID)
      @browser.click_and_wait(GridViewPageId::RESTORE_VIEW_ID)
      @browser.wait_for_element_visible(GridViewPageId::MAXIMIZE_VIEW_ID)
    end
  end

  def drag_and_drop_quick_add_card_to_ungrouped_grid_view
    drag_and_drop_quick_add_card_to('', '')
  end

  def drag_and_drop_quick_add_card_to(row_value, lane_value)
    @browser.with_ajax_wait do
      @browser.get_eval(<<-JAVASCRIPT)
        (function() {
          var locator = "css=#swimming-pool tr[row_value='#{row_value}'] td[lane_value='#{lane_value}']";

          if ("" === "#{row_value}" && "" === "#{lane_value}") {
            locator = "ungrouped";
          }

          var cwindow = selenium.browserbot.getCurrentWindow();
          var cell = selenium.browserbot.findElementOrNull(locator);
          if (null === cell) {
            throw "Could not find cell[#{row_value}][#{lane_value}] by locator: " + locator;
          }
          var element = cwindow.MagicCard.instance.element;
          cwindow.MagicCard.instance.onMagicCardDrop(element, cell);

          cwindow.MagicCard.instance.rememberRevertPosition(element, 0, 0);
        })();
      JAVASCRIPT
    end
  end

  def ensure_grid_settings_open
    if @browser.is_element_present("css=.show_grid_settings")
      @browser.click("css=.show_grid_settings")
      @browser.wait_for_element_visible("id=action_panel")
    end
  end

  def ensure_grid_settings_closed
    if @browser.is_element_present("css=.hide_grid_settings")
      @browser.click("css=.hide_grid_settings")
      @browser.wait_for_element_not_visible("id=action_panel")
    end
  end

  def group_columns_by(property)
    ensure_grid_settings_open
    @browser.wait_for_element_present group_by_columns_drop_link_id
    @browser.click(group_by_columns_drop_link_id)
    @browser.wait_for_element_visible group_by_columns_option_id(property)
    @browser.click_and_wait(group_by_columns_option_id(property))
    @browser.wait_for_element_not_visible class_locator('spinner')
    @browser.wait_for_all_ajax_finished
  end

  def group_rows_by(property)
    ensure_grid_settings_open
    @browser.wait_for_element_present group_by_rows_drop_link_id
    @browser.click(group_by_rows_drop_link_id)
    @browser.wait_for_element_present group_by_rows_option_id(property)
    @browser.click_and_wait(group_by_rows_option_id(property))
    @browser.wait_for_element_not_visible class_locator('spinner')
    @browser.wait_for_all_ajax_finished
  end

  #ungroup_by_columns_in_grid_view
  def ungroup_by_columns_in_grid_view
    group_columns_by(GridViewPageId::SELECT_PROPERTY_LINK)
  end

  def ungroup_by_row_in_grid_view
    group_rows_by(GridViewPageId::SELECT_PROPERTY_LINK)
  end

  def grid_sort_by(property)
    ensure_grid_settings_open
    @browser.wait_for_element_present sort_by_drop_link_id
    @browser.click(sort_by_drop_link_id)
    @browser.wait_for_element_present sort_by_option_id(property)
    @browser.click_and_wait(sort_by_option_id(property))
  end

  def color_by(property)
    ensure_grid_settings_open
    @browser.wait_for_element_present color_by_drop_link_id
    @browser.click(color_by_drop_link_id)
    @browser.wait_for_element_present color_by_option_id(property)
    @browser.click_and_wait(color_by_option_id(property))
  end

  def add_lanes(project, property_or_type, values, option={})
    values.each do |value|
      @browser.with_ajax_wait do
        @browser.click plus_drop_link_on_grid
        @browser.click("link=Add Column") if @browser.is_element_present("link=Add Column")
        @browser.wait_for_element_visible "css=.properties .ui-menu-item"
        @browser.click "css=.properties a:contains(#{value.inspect})"
      end
    end
  end

  def add_rows(values)
    values.each do |value|
      @browser.with_ajax_wait do
        @browser.click plus_drop_link_on_grid
        @browser.click("link=Add Row") if @browser.is_element_present("link=Add Row")
        @browser.wait_for_element_visible "css=.properties .ui-menu-item"
        @browser.click "css=.properties a:contains(#{value.inspect})"
      end
    end
  end

  def open_add_lane_dropdown
    @browser.with_ajax_wait do
      @browser.click plus_drop_link_on_grid
      @browser.wait_for_element_visible "css=.properties .ui-menu-item"
    end
  end

  def property_value_option_id(id, value)
    "#{id}_option_#{value}"
  end

  def rename_lane(old_value, new_value)
    @browser.with_ajax_wait do
      click_on_lane_header(old_value)
      @browser.type("name=new_lane_name", new_value)
      submit_form("group_lane_title_#{lane_htmlid(old_value)}")
    end
  end

  def click_on_lane_header(value)
    @browser.with_ajax_wait do
      @browser.click lane_id(value)
    end
  end

  def hide_grid_dimension(header, dimension="lane")
    @browser.with_ajax_wait do
      @browser.click "#{send(:"#{dimension}_htmlid", header)}_hide_lane"
    end
  end

  def create_new_lane(project, property, value)
    @browser.with_ajax_wait do
      @browser.click plus_drop_link_on_grid
      @browser.click("link=Add Column") if @browser.is_element_present("link=Add Column")
      @browser.wait_for_element_visible "css=.properties .ui-menu-item"
      @browser.click "css=.new-property"

      @browser.type("css=form.create input[type='text']", value)
      trigger_submit("form.create");
    end
  end

  def create_new_row(value)
    @browser.with_ajax_wait do
      @browser.click plus_drop_link_on_grid
      @browser.click("link=Add Row") if @browser.is_element_present("link=Add Row")
      @browser.wait_for_element_visible "css=.properties .ui-menu-item"
      @browser.click "css=.new-property"

      @browser.type("css=form.create input[type='text']", value)
      trigger_submit("form.create");
    end
  end

  def change_lane_heading(aggregation_type, aggregation_property = nil)
    ensure_grid_settings_open
    if aggregation_type.downcase == 'count'
      @browser.click(aggregate_type_drop_link_id)
      @browser.click(aggregate_type_option_id('count'))
      @browser.wait_for_all_ajax_finished
      return
    end

    if @browser.get_value(GridViewPageId::AGGREGATE_PROPERTY_SELECT_FIELD_ID).blank?
      @browser.click(aggregate_type_drop_link_id)
      @browser.click(aggregate_type_option_id(aggregation_type))
    else
      @browser.click(aggregate_type_drop_link_id)
      @browser.click_and_wait(aggregate_type_option_id(aggregation_type))
    end

    if aggregation_property
      @browser.click(aggregate_property_drop_link_id)
      @browser.click_and_wait(aggregate_property_option_id(aggregation_property))
      @browser.wait_for_all_ajax_finished
    end
  end

  def click_on_card_in_grid_view(card_number)
    if selenium_browser == "*googlechrome"
      @browser.get_eval("this.browserbot.getCurrentWindow().$('#{card_on_grid_view_id(card_number)}').click()")
    else
      @browser.click card_on_grid_view_id(card_number)
    end
    @browser.wait_for_card_popup(card_number)
  end

  def open_a_card_in_grid_view(project, card_number)
    @browser.open("/projects/#{project.identifier}/cards/#{card_number}")
  end

  def drag_and_drop_lanes(from_property_value, to_property_value)
    ensure_sidebar_closed
    @browser.wait_for_all_ajax_finished


    @browser.wait_for_element_visible(draggable(lane_header_htmlid(from_property_value)))
    drag_and_drop_js = %Q{
    var from = $j("#{draggable_selector(lane_header_htmlid(from_property_value))}");
    var to = $j("#{draggable_selector(lane_header_htmlid(to_property_value))}");
    var dx = to.offset().left - from.offset().left;
    var options = {
              dx: dx, dy: 0,
              interpolation: {
                duration: 1000,
                stepWidth: 5
              }
            };
    from.simulate("drag", options);
    to.simulate('drop');
    }
    @browser.run_script(drag_and_drop_js)

    @browser.wait_for_all_ajax_finished
    ensure_sidebar_closed
    @browser.wait_for_all_ajax_finished
  end

  def draggable(selector)
    css_locator(draggable_selector(selector))
  end

  def draggable_selector(selector)
    "table th##{selector}"
  end

  def drag_and_drop_card_from_lane(card_name, property, value, options = {:ajax => true})
    ensure_sidebar_closed

    drag_and_drop = Proc.new do
      @browser.drag_and_drop_to(card_name, lane_htmlid(value))
    end

    @browser.with_drag_and_drop_wait do
      if options[:ajax]
        @browser.with_ajax_wait do
          drag_and_drop.call
        end
      else
        drag_and_drop.call
      end
      sleep(1)
    end
    ensure_sidebar_closed
  end

  def drag_and_drop_card_to_cell(card, column_value, row_value, options = {:ajax => true})
    @browser.with_ajax_wait do
      ensure_sidebar_closed
    end

    drag_and_drop = Proc.new do
      @browser.drag_and_drop_to(card_id(card), grid_cell_html_id(column_value, row_value))
    end

    @browser.with_drag_and_drop_wait do
      if options[:ajax]
        @browser.with_ajax_wait do
          drag_and_drop.call
        end
      else
        drag_and_drop.call
      end
    end

    @browser.with_ajax_wait do
      ensure_sidebar_closed
    end
  end

  def click_on_transition_for_card_in_grid_view(card, transition)
    @browser.wait_for_element_visible card_on_grid_view_id(card.number)
    click_on_card_in_grid_view(card.number)
    @browser.wait_for_element_visible GridViewPageId::TRANSITIONS_BUTTON

    click_transition_link_on_card_in_grid_view(transition)
  end

  def click_transition_link_on_card_in_grid_view(transition)
    transition_element = transition_on_grid_view_id(transition)

    @browser.with_ajax_wait do
      @browser.click GridViewPageId::TRANSITIONS_BUTTON
    end

    @browser.wait_for_element_present transition_element

    @browser.with_ajax_wait do
      @browser.click transition_element
    end
  end

  def click_transition_link_on_transition_option_light_box(transition)
    @browser.with_ajax_wait do
      @browser.click grid_transition_link(transition)
    end
  end

  def group_by_and_order_by_drop_down_boxes_does_not_humanizing_properties_name(property_names)
    @browser.click(group_by_columns_drop_link_id)
    property_names.each do |property_name|
      @browser.assert_element_matches(group_by_columns_option_id(property_name), /#{property_name}/)
    end
    @browser.click(group_by_columns_drop_link_id)
    @browser.click(color_by_drop_link_id)
    property_names.each do |property_name|
      @browser.assert_element_matches(color_by_option_id(property_name), /#{property_name}/)
    end
    @browser.click(color_by_drop_link_id)
  end

  def turn_on_rank_mode
    return if rank_mode_on?
    @browser.with_ajax_wait { @browser.click(GridViewPageId::RANK_CHECKBOX) }
    script = %Q{
      (function(win){
        return (win.SwimmingPool.instance ? win.SwimmingPool.instance.operationMode : win.MingleUI.grid.instance.strategy).name === "ranked"
      })(selenium.browserbot.getCurrentWindow());
    }
    @browser.wait_for_condition script, 30000
  end

  def turn_off_rank_mode
    return unless rank_mode_on?
    @browser.with_ajax_wait { @browser.click(GridViewPageId::RANK_CHECKBOX) }
    script = %Q{
      (function(win){
        return (win.SwimmingPool.instance ? win.SwimmingPool.instance.operationMode : win.MingleUI.grid.instance.strategy).name === "unranked"
      })(selenium.browserbot.getCurrentWindow());
    }
    @browser.wait_for_condition script, 30000
  end

  def rank_mode_on?
    @browser.is_element_present("css=.rank_is_on")
  end

  def drag_and_drop_card_to(card_to_be_dragged, target_card)
    ensure_sidebar_closed
    @browser.with_ajax_wait do
      @browser.with_drag_and_drop_wait do
        @browser.drag_and_drop_to(card_id(card_to_be_dragged), card_id(target_card), 3)
      end
    end
  end

  def hide_the_grid_settings
    @browser.with_ajax_wait { ensure_grid_settings_closed }
  end

  def show_the_grid_settings
    @browser.with_ajax_wait { ensure_grid_settings_open }
  end

  def setup_card_type_property_for_cardtype(project, prop_name, cardtype_name)
    prop_def = setup_card_type_property_definition(prop_name)
    project.card_types.find_by_name(cardtype_name).add_property_definition(prop_def)
  end

  def setup_managed_text_property_for_cardtype(project, prop_name, prop_values, cardtype_name)
    prop_def = setup_managed_text_definition(prop_name, prop_values)
    project.card_types.find_by_name(cardtype_name).add_property_definition(prop_def)
  end

  def setup_user_property_for_cardtype(project, prop_name, cardtype_name)
    prop_def = setup_user_definition(prop_name)
    project.card_types.find_by_name(cardtype_name).add_property_definition(prop_def)
  end

  def setup_date_property_for_cardtype(project, prop_name, cardtype_name)
    prop_def = setup_date_property_definition(prop_name)
    project.card_types.find_by_name(cardtype_name).add_property_definition(prop_def)
  end

  def setup_managed_number_property_for_cardtype(project, prop_name, prop_values, cardtype_name)
    prop_def = setup_managed_number_list_definition(prop_name, prop_values)
    project.card_types.find_by_name(cardtype_name).add_property_definition(prop_def)
  end

  def setup_formula_property_for_cardtype(project, prop_name, formula, cardtype_name)
    prop_def = setup_formula_property_definition(prop_name, formula)
    project.card_types.find_by_name(cardtype_name).add_property_definition(prop_def)
  end

  def open_card_via_clicking_link_on_mini_card(card)
    @browser.click_and_wait(card_show_link_id(card))
  end

end
