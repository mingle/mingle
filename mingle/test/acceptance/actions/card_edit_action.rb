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

module CardEditAction
  NULL_VALUE = '(not set)'


  def open_card_create_page_for(project)
    @browser.open("/projects/#{project.identifier}/cards/new")
  end

  def open_card_for_edit(project, card)
    open_card(project, card)
    click_edit_link_on_card
  end

  def save_card
    sleep 2
    @browser.click save_card_button
    @browser.wait_for_text_present("successfully ")
    @browser.wait_for_all_ajax_finished
  end

  def save_card_with_flash
    @browser.click save_card_button
    @browser.wait_for_element_present("css=#flash")
  end

  def click_cancel
    @browser.click_and_wait CardEditPageId::CANCEL_LINK_ID
  end


  def type_card_description(description)
    enter_text_in_editor(description)
  end

  def type_comment_in_edit_mode(comment)
    @browser.type CardEditPageId::CARD_COMMENT_ID_ON_EDIT, comment
  end


  def on_card_edit_add_a_comment_that_is_not_a_murmur(comment)
    type_comment_in_edit_mode(comment)
    on_card_edit_check_on_murmur_this_comment
  end

  def on_card_edit_add_a_comment_that_is_also_a_murmur(comment)
    type_comment_in_edit_mode comment
    assert_murmur_this_comment_is_checked_on_card_show
    save_card
  end

  def on_card_edit_check_on_murmur_this_comment
    unless @browser.assert_checked(CardEditPageId::MURMUR_THIS_COMMENT_CHECKBOX)
      @browser.click CardEditPageId::MURMUR_THIS_COMMENT_CHECKBOX
    end
  end

  def on_card_edit_uncheck_murmur_this_comment
    if @browser.is_checked(CardEditPageId::MURMUR_THIS_COMMENT_CHECKBOX)
      @browser.click CardEditPageId::MURMUR_THIS_COMMENT_CHECKBOX
    end
  end
  def add_new_value_to_property_on_card_edit(project, property, value)
    add_new_value_to_property_on_card(project, property, value, 'edit')
  end

  def set_properties_in_card_edit(properties)
    card_type_key = properties.keys.detect{ |key| key.to_s.downcase == 'type' }

    if card_type_key
      card_type = properties.delete(card_type_key)
      set_card_type_on_card_edit(card_type)
    end

    properties.each do |name, value|
      value = NULL_VALUE if value.nil?
      if @browser.is_element_present(property_editor_id(name, 'edit'))
        @browser.click property_editor_id(name, 'edit')
        @browser.click droplist_option_id(name, value, 'edit')
      elsif @browser.is_element_present(editlist_link_id(name, 'edit'))
        @browser.click editlist_link_id(name, 'edit')
        @browser.type editlist_inline_editor_id(name, 'edit'), value
      else
        raise "Can't find the property drop list with the name '#{name}'"
      end
    end
  end

  def edit_card(orginal_attributes)
    attributes = orginal_attributes.clone
    name = attributes.delete(:name)
    description = attributes.delete(:description)
    discussion = attributes.delete(:discussion)

    @browser.open @browser.get_location
    @browser.click_and_wait show_latest_link if @browser.is_element_present(show_latest_link)
    click_edit_link_on_card

    type_card_name(name) if name
    type_card_description(description) if description
    type_comment_in_edit_mode(discussion) if discussion
    set_properties_in_card_edit attributes
    save_card
  end

  def set_card_type_on_card_edit(card_type)
    @browser.click(card_type_editor_id("edit"))
    @browser.click(card_type_option_id(card_type, "edit"))
    @browser.wait_for_all_ajax_finished
  end

  def click_save_and_add_another_link
    @browser.click_and_wait(save_and_add_another_button)
  end

  def open_card_selector_for_property_on_card_edit(property)
    open_card_selector_for_property(property, "edit")
  end

  def click_save_for_card_type_change
    @browser.click save_card_button
    confirm_card_type_change
  end

  def set_relationship_properties_on_card_edit(properties)
    set_relationship_properties("edit", properties)
  end

  def click_property_on_card_edit(property)
    click_on_card_property(property, "edit")
  end

  def select_value_in_drop_down_for_property_on_card_edit(property, value)
    select_property_drop_down_value(property, value, "edit")
  end

  def type_keyword_to_search_value_for_property_on_card_edit(property, keyword)
    enter_search_value_for_property_editor_drop_down(property, keyword, "edit")
  end

  def click_bolded_keyword_part_of_value_on_card_edit(property, value)
    @browser.click edit_property_search_hightlighted_id(property,value)
  end

  def click_comment_tab_on_card
    @browser.with_ajax_wait do
      @browser.click CardEditPageId::COMMENT_TAB_ID
    end
  end

  def click_on_attach_image
     @browser.click CardEditPageId::INSERT_IMAGE_TOOL_ID
     @browser.wait_for_element_present(CardEditPageId::UPLOAD_IMAGE_FIELD)
  end

  def attach_image(image_path)
    click_on_attach_image
    @browser.type(CardEditPageId::UPLOAD_IMAGE_FIELD, image_path)
    @browser.click('link=Add')
    @browser.wait_for_element_not_present(CardEditPageId::UPLOAD_IMAGE_FIELD)
  end

  def create_free_hand_macro(macro_content)
    enter_text_in_macro_editor(macro_content)
    click_ok_on_macro_editor

    @browser.wait_for_element_not_visible("css=a[title='OK']") if !@browser.is_element_present("css=.error")
    @browser.wait_for_element_present CardEditPageId::RENDERABLE_CONTENTS if !@browser.is_element_present("css=.error")

    # enter a newline, regardless of which editor instance (card, page, card default) we're on
    # to ensure that the cursor is no longer at this macro. otherwise, subsequent calls to this
    # method will fail.
    type_in_editor "\\n"
  end

  def click_cancel_on_wysiwyg_editor
    @browser.with_ajax_wait do
      @browser.click class_locator('cke_dialog_close_button')
    end
  end

  def create_free_hand_macro_and_save(macro_content)
    create_free_hand_macro(macro_content)
    save_card
    wait_for_card_contents_to_load
  end

  def click_toolbar_wysiwyg_editor(title)
    @browser.wait_for_element_visible("css=.cke_toolbox")
    button = "css=a[title='#{title}']"
    if using_ie?
      @browser.mouse_down(button)
      @browser.mouse_up(button)
    else
      sleep 1
      @browser.click button
    end
  end

  def wait_for_chart_editor
    @browser.wait_for_element_present class_locator('chart-editor')
  end

  def enter_text_in_macro_editor(macro_content)
    click_toolbar_wysiwyg_editor('Insert Macro')
    @browser.wait_for_element_present(class_locator('cke_dialog_contents_body'))
    @browser.type(class_locator('cke_dialog_ui_input_textarea', 1), '')
    sleep 0.5
    @browser.type(class_locator('cke_dialog_ui_input_textarea', 1), macro_content)
    sleep 0.5
  end

  def edit_macro(macro_type)
    #macro_type could be table, stacked-bar-chart, data-series-chart, pie-chart,ratio-bar-chart
    wait_for_wysiwyg_editor_ready
    if macro_type == 'table' || macro_type == 'pivot-table' then
      @browser.mouse_move "css=table.macro"
    else
      @browser.mouse_move "css=div.macro"
    end
    @browser.wait_for_element_visible('css=img.macro-edit-button')
    @browser.click "css=img.macro-edit-button"
    @browser.wait_for_element_present(class_locator('cke_dialog_ui_input_textarea', 1))
    sleep 1
  end


  def click_ok_on_macro_editor
    @browser.click("css=a[title='OK']")
  end

  def click_preview
    @browser.click("link=Preview")
    sleep 1
    @browser.wait_for_element_present("css=#macro_preview *")
  end

  def click_insert_on_macro_editor
    @browser.click("link=Insert")
  end

  def insert_average_query(query)
    click_toolbar_wysiwyg_editor('Insert Average')
    @browser.wait_for_element_present('macro_editor_average_query')
    @browser.type('macro_editor_average_query', query)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
  end

  def insert_value_query(query)
    click_toolbar_wysiwyg_editor('Insert Value')
    @browser.wait_for_element_present('macro_editor_value_query')
    @browser.type('macro_editor_value_query', query)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
  end

  def open_project_variable_macro_editor_and_type_plv(plv_name)
    click_project_variable_macro
    @browser.wait_for_element_present('macro_editor_project-variable_name')
    @browser.type('macro_editor_project-variable_name', plv_name)
  end

  def insert_project_macro
    @browser.wait_for_element_visible("css=a[title='Insert Project']")
    click_toolbar_wysiwyg_editor('Insert Project')
  end

  def insert_project_macro_and_save
    insert_project_macro
    save_card
    @browser.wait_for_element_present "notice"
  end

  def insert_table_query(query)
    click_toolbar_wysiwyg_editor('Insert Table Query')
    @browser.wait_for_element_present('macro_editor_table-query_query')
    @browser.type('macro_editor_table-query_query', query)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    save_card
  end

  def insert_table_view_macro(query)
    click_toolbar_wysiwyg_editor('Insert Table View')
    @browser.wait_for_element_visible('macro_editor_table-view_view')
    sleep 1
    @browser.type('macro_editor_table-view_view', query)
    click_insert_on_macro_editor
  end

  def insert_table_view_macro_and_save(query)
    click_toolbar_wysiwyg_editor('Insert Table View')
    @browser.wait_for_element_present('macro_editor_table-view_view')
    @browser.type('macro_editor_table-view_view', query)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    save_card
  end

  def insert_pivot_table_macro(column,rows)
    click_toolbar_wysiwyg_editor('Insert Pivot Table')
    @browser.wait_for_element_present('macro_editor_pivot-table_columns')
    @browser.type('macro_editor_pivot-table_columns', column)
    @browser.type('macro_editor_pivot-table_rows', rows)
    @browser.click("link=-")
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    save_card
    wait_for_card_contents_to_load
  end

  def insert_stack_bar_chart_macro(conditions, labels, data)
    click_toolbar_wysiwyg_editor('Insert Stacked Bar Chart')
    @browser.wait_for_element_present('stacked-bar-chart_series_0_data_parameter')
    @browser.type('macro_editor_stacked-bar-chart_conditions', conditions)
    @browser.type('macro_editor_stacked-bar-chart_labels', labels)
    @browser.click('stacked-bar-chart_remove_series_button_1')
    @browser.type('stacked-bar-chart_series_0_data_parameter', data)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    save_card
  end

  def insert_data_series_chart_macro(conditions, data)
    click_toolbar_wysiwyg_editor('Insert Data Series Chart')
    @browser.wait_for_element_present('data-series-chart_series_0_data_parameter')
    @browser.type('macro_editor_data-series-chart_conditions', conditions)
    @browser.click('data-series-chart_remove_series_button_1')
    # sleep 1
    @browser.type('data-series-chart_series_0_data_parameter', data)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    save_card
  end

  def insert_daily_history_chart_macro(aggregate, start_date, end_date, chart_conditions, series_conditions)
    click_toolbar_wysiwyg_editor('Insert Daily History Chart')
    @browser.wait_for_element_present('daily-history-chart_series_0_conditions_parameter')
    @browser.type('macro_editor_daily-history-chart_aggregate', aggregate)
    @browser.type('macro_editor_daily-history-chart_start-date', start_date)
    @browser.type('macro_editor_daily-history-chart_end-date', end_date)
    @browser.type('macro_editor_daily-history-chart_chart-conditions', chart_conditions)
    @browser.click('daily-history-chart_remove_series_button_1')
    @browser.type('daily-history-chart_series_0_conditions_parameter', series_conditions)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    @browser.wait_for_element_present(CardEditPageId::RENDERABLE_CONTENTS)
    @browser.assert_text_present_in(CardEditPageId::RENDERABLE_CONTENTS,"Your daily history chart will display upon saving")
    save_card
    wait_for_card_contents_to_load
  end

  def insert_ratio_bar_chart(totals,restrict_ratio_with)
    click_toolbar_wysiwyg_editor('Insert Ratio Bar Chart')
    @browser.wait_for_element_present('macro_editor_ratio-bar-chart_totals')
    @browser.type('macro_editor_ratio-bar-chart_totals', totals)
    @browser.type('macro_editor_ratio-bar-chart_restrict-ratio-with', restrict_ratio_with)
    click_insert_on_macro_editor
    click_cancel_on_wysiwyg_editor
    save_card
  end

  def wait_for_wysiwyg_editor_ready
    ready_condition = [
      "selenium.browserbot.getCurrentWindow().CKEDITOR",
      "selenium.browserbot.getCurrentWindow().CKEDITOR.mingle",
      "selenium.browserbot.getCurrentWindow().CKEDITOR.mingle.ready",
    ].join(" && ")
    ready_condition = "!!(#{ready_condition})" # force to boolean since the above condition can return null
    @browser.ruby_wait_for_condition(ready_condition, 15000)
  end

  def type_in_editor(text)
    @browser.get_eval <<-JS
      var win = selenium.browserbot.getCurrentWindow();
      win.$j.each(win.CKEDITOR.instances, function(name, editor) {
        editor.insertText('#{text}');
      });
    JS
  rescue Exception => e
    puts %Q[Failed to type text in CKEDITOR:
      text: #{text.inspect}
      error: #{e.message}
    ]
  end

  def enter_text_in_editor(text)
    wait_for_wysiwyg_editor_ready
    @browser.click(CardEditPageId::RENDERABLE_CONTENTS)
    sleep 1
    type_in_editor text
  end

  def click_project_variable_macro
    click_toolbar_wysiwyg_editor('Insert Project Variable')
  end

  def create_card_for_edit(project, card_name, options={:wait => false})
    add_card_via_quick_add(card_name, options)
    card = project.cards.find_by_name(card_name)
    open_card(project, card)
    click_edit_link_on_card
    return card
  end

  def select_stack_bar_chart_macro_editor
    click_toolbar_wysiwyg_editor("Insert Stacked Bar Chart")
    @browser.wait_for_element_present(macro_editor_popup)
    @browser.wait_for_element_visible "stacked-bar-chart_series_0_data_parameter"
    @browser.wait_for_element_visible "stacked-bar-chart_series_1_data_parameter"
  end

  def wait_for_card_contents_to_load
    @browser.wait_for_element_present('css=.wiki')
  end


end
