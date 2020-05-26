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

module ChartAssertionPage
  def assert_table_column_headers_and_order(table_identifier, *column_headers)
    @browser.wait_for_element_not_present('css=.async-macro-loader')
    is_pivot = table_identifier.split('-').first == 'pivot'

    column_headers.each_with_index do |column_header, i|
      n = is_pivot ? i + 1 : i
      actual = @browser.get_text("css=.main_inner tr:first th:nth-child(#{n + 1})").normalize_whitespace
      assert_equal column_header.to_s, actual, "Expected table column header : '#{column_header}', actual: '#{actual}'"
    end
  end

  def assert_table_row_headers_and_order(table_identifier, *row_headers)
    row_headers.each_with_index do |row_header, i|
      actual = @browser.get_text("css=.main_inner tr:nth-child(#{i + 2}) th:first").normalize_whitespace
      assert_equal row_header.to_s, actual, "Expected table row header : '#{row_header}', actual: '#{actual}'"
    end
  end

  def assert_table_row_data_for(table_identifier, options)
    @browser.wait_for_element_not_present('css=.async-macro-loader')
    cell_values = options[:cell_values]
    row_number = options[:row_number]
    actual_cell_values = @browser.get_eval(%Q[
      var results = [];
      var win = selenium.browserbot.getCurrentWindow();
      win.$j(".main_inner tr:eq(#{row_number}) td").each(function(idx, el) {
        results.push(win.$j.trim(win.$j(el).text().replace(/\s+/g, " ")));
      });
      results.join(",");
    ])
    cell_values = cell_values.join(',')

    #remove double byte space IE given
    actual_cell_values = actual_cell_values.to_s.gsub(/#{ "" << 194 << 160 }/, '')
    cell_values = cell_values.to_s.gsub(/#{"" << 194 << 160 }/, '')
    assert_equal cell_values, actual_cell_values, "Expected table row data: '#{cell_values}'\nactual: '#{actual_cell_values}'"
  end

   def assert_table_values(table_identifier, row, col, expected, options = { :unescape_html => true})
      actual = @browser.get_eval(%{
        this.browserbot.getCurrentWindow().$('#{table_identifier}').down('TR', #{row}).getElementsByTagName('TD')[#{col}].innerHTML#{'.unescapeHTML()' if options[:unescape_html]}
      })

      if Regexp === expected
        actual =~ expected || raise(SeleniumCommandError.new("Table cell is not =~ #{expected.inspect}. It was '#{actual}'."))
      else
        actual.strip.gsub(/\s/, '') == expected.to_s.gsub(/\s/, '') || raise(SeleniumCommandError.new("Table cell is not '#{expected}' it was '#{actual.strip}'"))
      end
    end



    def assert_table_cell(table_index, row, column, expected_result, options = {})
      @browser.assert_table_cell("css=table:nth-child(#{table_index + 1})", row, column, expected_result)
    end

    def assert_table_cell_on_preview(row, column, expected_result)
      @browser.assert_table_cell("css=#card-description table", row, column, expected_result)
    end

    def assert_text_is_bold(text)
      @browser.assert_text_present("*#{text}*")
    end

    def assert_contents_on_page(*contents)
      contents.each { |content| @browser.assert_text_present_in(WikiPageId::VIEW_PAGE_CONTENT_ID, content)}
    end

    def assert_contents_on_preview(*contents)
      contents.each { |content| @browser.assert_text_present_in(WikiPageId::PREVIEW_PANEL_CONTAINER_ID, content)}
    end

    def assert_mql_error_messages(*error_messages)
      error_messages.each_with_index do |error_message, i|
        actual_error_message = @browser.get_eval("#{class_locator('error')}.innerHTML.unescapeHTML()")
        assert_equal_ignoring_spaces(error_message , actual_error_message)
      end
    end

    def assert_cross_project_reporting_restricted_message_for(project, id='content')
      project = project.identifier if project.respond_to?(:identifier)
      @browser.assert_element_matches(id, /This content contains data for one or more projects of which you are not a member. To see this content you must be a member of the following project: #{project}./)
    end

    def assert_mql_syntax_error_message_present
      @browser.assert_element_present(class_locator('error'))
      @browser.assert_element_matches(class_locator('error'), Regexp.new(Regexp.escape("Error in data-series-chart macro: Please check the syntax of this macro. The macro markup has to be valid")))
    end

    def assert_chart(label, value)
      actual = @browser.get_eval(%{
        this.browserbot.getCurrentWindow().$('value_for_#{label}').innerHTML
      })
      assert_equal value, actual
    end

    def user_should_only_see_correct_result_shown_on_data_series_chart(result={})
       result.each do |key, value|
         assert_chart(key,value)
       end
     end


    def assert_value_not_set(text)
      assert_equal false, @browser.is_text_present(text)
    end

    #macro editor
    def assert_should_see_macro_editor_lightbox
      @browser.assert_element_present(macro_editor_popup)
    end

    def assert_should_not_see_macro_editor_lightbox
      @browser.assert_element_not_present(macro_editor_popup)
    end

    def assert_order_of_macro_in_dropdown
      macro=['average','data-series-chart','pie-chart','pivot-table','project','project-variable','ratio-bar-chart','stack-bar-chart','table-query','table-view','value']
      @browser.assert_values_in_drop_down_are_ordered('macro_type',macro)
    end


    def assert_macro_parameters_field_exist(macro_name, parameters)
      @browser.assert_visible(macro_name_panel(macro_name))
       parameters.each do |para|
       assert_macro_parameter_field_exist(macro_name, para.to_s.gsub('_','-'))
      end
    end

    def assert_chart_macro_series_level_parameters_field_exist(macro_name, parameters)
      @browser.assert_visible(macro_name_panel(macro_name))
      parameters.each do |para|
      assert_chart_macro_series_level_parameter_field_exist(macro_name, para.to_s.gsub('_','-'))
     end
    end

    def assert_values_of_parameters_of_macro(macro_name, parameters={})
     parameters.each do |key, value|
        @browser.assert_value(html_name_for_macro(macro_name, key), value)
     end
    end

    def assert_order_of_parameters_on_macro_editor(macro_name, parameters)
      parameters.each_with_index do |para, index|
       @browser.assert_ordered(html_name_for_macro(macro_name, para), html_name_for_macro(macro_name, parameters[index+1])) unless para == parameters.last
     end
    end

    def assert_macro_parameter_field_exist(macro_name, param)
      @browser.assert_element_present(html_name_for_macro(macro_name, param))
    end

    def assert_chart_macro_series_level_parameter_field_exist(macro_name, param)
      @browser.assert_element_present("macro_editor[#{macro_name}][series][0][#{param}]")
    end

    def assert_macro_parameters_visible(macro_name, parameters)
      parameters.each do |para|
        @browser.assert_visible(macro_name_parameters_visibility(macro_name,para))
      end
    end

    def assert_macro_parameters_not_visible(macro_name, parameters)
      parameters.each do |para|
        @browser.assert_not_visible(macro_name_parameters_visibility(macro_name,para))
      end
    end

    def assert_chart_macro_series_level_parameters_visible(macro_name, index, parameters)
      parameters.each do |para|
        @browser.assert_visible(macro_name_parameter_id(macro_name,index,para))
      end
    end

    def assert_chart_macro_series_level_parameters_not_visible(macro_name, index, parameters)
      parameters.each do |para|
        @browser.assert_not_visible(macro_name_parameter_id(macro_name,index,para))
      end
    end

    def assert_page_content(expected_content)
      actural_content = @browser.get_value(WikiPageId::EDIT_PAGE_CONTENT_ID)
      actural_content_ignore_ie_difference= actural_content.to_s.gsub("\r\n","\n")
      assert_equal(expected_content, actural_content_ignore_ie_difference)
    end

    def assert_add_macro_parameter_icon_present(chart_type)
      @browser.assert_visible(add_optional_parameter_droplink(chart_type))
    end

    def assert_add_macro_parameter_icon_not_present(chart_type)
      @browser.assert_not_visible(add_optional_parameter_droplink(chart_type))
    end

    def assert_remove_macro_parameter_icon_present_for(chart_type, parameter)
      remove_optional_parameter_id(chart_type,parameter)
    end

    def assert_remove_macro_parameter_icons_present_for(chart_type, parameters)
      parameters.each do |para|
        assert_remove_macro_parameter_icon_present_for(chart_type, para)
      end
    end

    def assert_remove_macro_parameter_icon_not_present_for(chart_type, parameter)
      if @browser.is_element_present(remove_optional_parameter_id(chart_type,parameter))
        @browser.assert_not_visible(remove_optional_parameter_id(chart_type,parameter))
      else
        @browser.assert_element_not_present(remove_optional_parameter_id(chart_type,parameter))
      end
    end

    def assert_remove_macro_parameter_icons_not_present_for(chart_type, parameters)
      parameters.each do |para|
        assert_remove_macro_parameter_icon_not_present_for(chart_type, para)
      end
    end

    def assert_parameter_present_on_drop_list_for_adding(macro_type, parameter)
      @browser.assert_element_present(optional_parameter_chart_option_id(macro_type,parameter))
    end

    def assert_series_parameter_present_on_drop_list_for_adding(macro_type, series_index, parameter)
      @browser.assert_element_present(series_level_optional_parameter_chart_option_id(macro_type,series_index,parameter))
    end

    def assert_parameter_not_present_on_drop_list_for_adding(macro_type, parameter)
      @browser.assert_element_not_present(optional_parameter_chart_option_id(macro_type,parameter))
    end

    def assert_series_parameter_not_present_on_drop_list_for_adding(macro_type, series_index, parameter)
      @browser.assert_element_not_present(series_level_optional_parameter_chart_option_id(macro_type,series_index,parameter))
    end

    def assert_macro_parmeter_has_initial_value(macro_type, para)
      if para == 'color'
        parameter_id = "#{macro_type}_color_parameter"
        @browser.assert_visible(css_locator("p##{parameter_id} span[class=color_block]"))
      end
      if para == 'three-d' || para == 'totals'
        value = @browser.get_eval(%{
          this.browserbot.getCurrentWindow().$('macro_editor_#{macro_type}_#{para}_false').checked
        })
        raise SeleniumCommandError.new("Initial value for #{para} is not false.") unless value == 'true'
      end
      if para == 'empty-columns'|| para == 'empty-rows' || para == 'links'
        value = @browser.get_eval(%{
          this.browserbot.getCurrentWindow().$('macro_editor_#{macro_type}_#{para}_true').checked
        })
        raise SeleniumCommandError.new("Initial value for #{para} is not true.") unless value == 'true'
      end
    end

    def assert_macro_parmeters_have_initial_value(macro_type,paras)
      paras.each do |para|
        assert_macro_parmeter_has_initial_value(macro_type, para)
      end
    end

    def assert_add_chart_macro_series_level_parameter_icon_present(chart_type, index=0)
      @browser.assert_visible(series_level_add_optional_parameter_droplink(chart_type,index))
    end

    def assert_add_chart_macro_series_level_parameter_icon_not_present(chart_type, index=0)
      @browser.assert_not_visible(series_level_add_optional_parameter_droplink(chart_type,index))
    end

    def assert_add_chart_macro_series_icon_present(chart_type, index=0)
      @browser.assert_element_present(add_series_id(chart_type,index))
    end

    def assert_remove_chart_macro_series_level_parameter_icons_present(chart_type, chart_series, paras)
      paras.each do |para|
        assert_remove_chart_macro_series_level_parameter_icon_present(chart_type, chart_series, para)
      end
    end

    def assert_remove_chart_macro_series_level_parameter_icons_not_present(chart_type, chart_series, paras)
      paras.each do |para|
        assert_remove_chart_macro_series_level_parameter_icon_not_present(chart_type, chart_series, para)
      end
    end

    def assert_remove_chart_macro_series_level_parameter_icon_present(chart_type, chart_series, para)
      remove_chart_series_optional_parameter_id(chart_type,chart_series,para)
    end

    def assert_remove_chart_macro_series_level_parameter_icon_not_present(chart_type, chart_series, para)
      if @browser.is_element_present(remove_chart_series_optional_parameter_id(chart_type,chart_series,para))
        @browser.assert_not_visible(remove_chart_series_optional_parameter_id(chart_type,chart_series,para))
      else
        @browser.assert_element_not_present(remove_chart_series_optional_parameter_id(chart_type,chart_series,para))
      end
    end

    def assert_remove_chart_macro_series_icon_present(chart_type, index=0)
      @browser.assert_visible(remove_series_id(chart_type,index))
    end

    def assert_remove_chart_macro_series_icon_not_present(chart_type, index=0)
      @browser.assert_not_visible(remove_series_id(chart_type,index))
    end

    def assert_series_visible(chart_type, index = 0)
      @browser.assert_visible(series_container_index_id(chart_type,index))
    end

    def assert_series_not_visible(chart_type, index = 0)
      @browser.assert_element_not_present(series_container_index_id(chart_type,index))
    end

    def assert_radio_button_series_level_parameter_set_to(chart_type, index, parameter_name, value)
      @browser.assert_checked(css_locator('input[name="macro_editor[' + chart_type + '][series][' + index.to_s + '][' + parameter_name + ']"][value=' + value + ']'))
    end

    def assert_radio_button_series_level_parameter_not_set_to(chart_type, index, parameter_name, value)
      @browser.assert_not_checked(css_locator('input[name="macro_editor[' + chart_type + '][series][' + index.to_s + '][' + parameter_name + ']"][value=' + value + ']'))
    end

    def assert_url_error_message_for_google_maps_macro
      @browser.assert_text_present("google-maps macro: Parameter src must be a recognized Google Maps URL.")
    end

    def assert_url_error_message_for_google_calendar_macro
      @browser.assert_text_present("google-calendar macro: Parameter src must be a recognized Google Calendar URL.")
    end


end


module WikiPage
  include ChartAssertionPage


  def assert_warning_message_of_expired_wiki_content_present
    @browser.assert_text_present(WikiPageId::WARNING_OF_VIEWING_OLD_WIKI_CONTENT)
  end

  def assert_page_history_for(versioned_type, identifier)
    #load_card_history
    HistoryAssertion.new(@browser, versioned_type, identifier)
  end

  def assert_warning_message_of_expired_wiki_content_not_present
    @browser.assert_text_not_present(WikiPageId::WARNING_OF_VIEWING_OLD_WIKI_CONTENT)
  end

  def assert_non_existant_wiki_link_present
     @browser.assert_element_present(wiki_link_not_present)
   end

   def assert_non_existant_wiki_page_link_not_present
     @browser.assert_element_not_present(wiki_link_not_present)
   end

   def assert_version_info_on_page(message)
     @browser.assert_element_matches(css_locator('.version-info'), /#{message}/)
   end

   def assert_opened_wiki_page(page_name)
     @browser.assert_element_matches('page-name', /#{page_name}/)
     @browser.assert_element_not_present(css_locator('textarea#page_content'))
   end

   def assert_wiki_favorites_present(project, *wiki_favorites)
      wiki_favorites.each do |wiki_favorite|
        @browser.assert_element_present(wiki_favorite_present(wiki_favorite))
      end
    end

    def assert_wiki_favorites_not_present(project, *wiki_favorites)
      wiki_favorites.each do |wiki_favorite|
        @browser.assert_element_not_present(wiki_favorite_present(wiki_favorite))
      end
    end

    def assert_favorite_link_on_wiki_action_bar_as(link)
      title = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('top_favorite_link').title")
      assert_equal(link, title)
    end

    def assert_tab_link_on_wiki_action_bar_as(link)
      title = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('top_tab_link').title")
      assert_equal(link, title)
    end

    def assert_tab_link_not_present_on_wiki_action_bar
      @browser.assert_element_not_present(WikiPageId::REMOVE_TAB_LINK)
    end

    def assert_favorites_link_not_present_on_wiki_action_bar
      @browser.assert_element_not_present(WikiPageId::MAKE_TEAM_FAVORITE_LINK)
    end

    def assert_special_header_present(header_name)
      @browser.assert_element_present(header_name_link(header_name))
    end

    def assert_special_header_not_present(header_name)
      @browser.assert_element_not_present(header_name_link(header_name))
    end

    def assert_page_link_present(page_number)
      @browser.assert_element_present page_number_link(page_number)
    end

    def assert_page_link_not_present(page_number)
      @browser.assert_element_not_present page_number_link(page_number)
    end

    def assert_on_page(project, page_number, tab="All", favorite_id=nil)
      project = project.identifier if project.respond_to? :identifier
      favorite_param = favorite_id ? "favorite_id=#{favorite_id}&" : ""
      @browser.assert_location("/projects/#{project}/cards/list?#{favorite_param}page=#{page_number}&style=list&tab=#{tab}")
      @browser.assert_element_not_present(page_number_link(page_number))
    end

    def current_page_number_should_be(page_number)
      @browser.assert_element_text(css_locator('span.page-num.highlight-warning', 0), page_number.to_s)
    end

    def assert_not_on_page(page_number)
      @browser.assert_element_present(page_number_link(page_number))
    end

    def assert_hide_too_many_macros_link_not_present
      @browser.assert_element_not_present(css_locator("div#too_many_macros_warning a[onclick]"))
    end

end
