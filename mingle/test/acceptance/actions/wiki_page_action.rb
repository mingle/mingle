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

module ChartGeneratorAction
      #macro editors

      def select_macro_editor(macro_name)
        click_toolbar_wysiwyg_editor(macro_name)
        @browser.wait_for_element_present(class_locator('chart-editor'))
        @browser.wait_for_all_ajax_finished
      end

      def open_wiki_page_in_edit_mode(page_name = 'test page')
        wiki = @project.pages.find_or_create_by_name(page_name)
        open_wiki_page_for_edit(@project, wiki.name)
        wait_for_wysiwyg_editor_ready
        wiki
      end

      def submit_macro_editor
        click_insert_on_macro_editor
        # click_cancel_on_wysiwyg_editor
        @browser.wait_for_element_present(CardEditPageId::RENDERABLE_CONTENTS)
      end

      def select_macro_via_dropdown(macro_name)
          @browser.select(WikiPageId::MACRO_TYPE_DROPDOWN_ID, macro_name)
          @browser.wait_for_all_ajax_finished
      end

      def open_macro_editor_with(values)
        macro_name = values.delete(:name)
        go_to_card_edit_and_open_macro_editor(macro_name)
        type_macro_parameters(macro_name, values)
      end

      def open_macro_editor_without_param_input(name)
        open_macro_editor_with({:name => name})
      end

      def open_macro_editor_for_card_named(name, values)
        open_card(@project, @project.cards.find_by_name(name).number)
        click_edit_link_on_card
        macro_name = values.delete(:name)
        select_macro_editor(macro_name)
        type_macro_parameters(macro_name, values)
      end

      def go_to_card_edit_and_open_macro_editor(macro_name)
        new_card = create_card!(:name => 'new card')
        assertion_card = create_card!(:name => 'assertion card')
        open_card(@project, assertion_card.number)
        click_edit_link_on_card
        select_macro_editor(macro_name)
      end

      def type_macro_parameters(macro_name, parameters={})
        parameters.each do |para, value|
          @browser.type(html_name_for_macro(macro_name, para.to_s.gsub('_','-')), value)
        end
      end

      def type_chart_macro_series_level_parameter_for(macro_name, series_index, parameters={})
        parameters.each do |para, value|
        @browser.type(macro_editor_series_level_parameter_id(macro_name,series_index, para), value)
        end
      end

      #macro editor preview
      def preview_macro
        @browser.with_ajax_wait do
          @browser.click(WikiPageId::PREVIEW_MACRO_BUTTON_ID)
        end
      end


      def preview_content_should_include(*parts)
        preview_content = @browser.get_text(WikiPageId::MACRO_PREVIEW_CONTENT_ID)
        parts.each do |part|
          assert_include part, preview_content.normalize_whitespace
        end
      end

      def add_macro_and_save_on(project, macro_content,options={})
        edit_overview_page
        create_free_hand_macro(macro_content)
        click_save_link
        navigate_to_project_overview_page(project)
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
      end

      def add_value_query_and_save_on(value_or_aggregate, *condition_string)
        query = generate_value_query(value_or_aggregate, condition_string)
        paste_query_and_save(query)
      end

      def add_value_query(value_or_aggregate, *condition_string)
        query = generate_value_query(value_or_aggregate, condition_string)
        paste_query(query)
      end

      def add_average_query_and_save_on(value, *condition_string)
        query = generate_average_query(value, condition_string)
        paste_query_and_save(query)
      end

      def add_table_query_and_save_on(select_options, conditions = [], options = {})
        query = generate_table_query(select_options, conditions, options)
        paste_query_and_save(query)
        @table_name
      end

      def add_table_query(select_options, conditions = [], options = {})
        query = generate_table_query(select_options, conditions, options)
        paste_query(query)
        @table_name
      end

      def add_table_view_query_and_save(view_name)
        query = generate_table_view_query(view_name)
        paste_query_and_save(query)
        "table-view-#{view_name.gsub("\s",'-')}"
      end

      def add_ratio_bar_chart_and_save_on_overview_page(property, aggregate, options={})
        query = generate_ratio_bar_chart(property, aggregate, options)
        edit_overview_page
        paste_query_and_save(query)
        reload_current_page if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        "ratio-bar-chart-#{property.gsub("\s", '-')}"
      end



      def add_pie_chart_and_save_on_overview_page(property, aggregate, options={})
        query = generate_pie_chart(property, aggregate, options)
        edit_overview_page
        paste_query_and_save(query)
        reload_current_page if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
      end

      def add_pie_chart_without_aggregate_and_save_for(property)
        edit_overview_page
        paste_query_and_save(%{
             pie-chart
              data: SELECT #{property}
         })
      end

      def add_table_query_and_save_for_cross_project(select_options, condition_string, cross_project, options = {})
        query = generate_table_query_for_cross_project(select_options, condition_string, cross_project, options)
        paste_query_and_save(query)
        @table_name
      end

      def add_data_series_chart_and_save_on_overview_page(options = {})
        query = generate_data_series_chart_query(options)
        edit_overview_page
        paste_query_and_save(query)
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        @table_name
      end

      def add_data_series_chart_with_no_series_and_save_for(options = {})
        query = generate_a_data_series_chart_with_no_series(options)
        edit_overview_page
        paste_query_and_save(query)
        @table_name
      end

      def add_data_series_chart_with_wrong_data_query_and_save_for(query)
        edit_overview_page
        create_free_hand_macro(%{
             data-series-chart
              series:
              - data: #{query}
         })
      end

      def add_data_series_chart_and_save_on_overview_page_to_test_optional_parameter(query,optional_parameter)
        edit_overview_page
        create_free_hand_macro(%{
             data-series-chart
              #{optional_parameter}
              series:
              - data: #{query}
         })
      end

      def add_stack_bar_chart_and_save_on_overview_page(options = {})
        query = generate_stack_bar_chart_query(options)
        edit_overview_page
        paste_query_and_save(query)
        reload_current_page if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        @table_name
      end

      def add_stack_bar_chart_with_two_series_and_save_for(options = {})
        query = generate_stack_bar_chart_with_two_series_query(options)
        paste_query_and_save(query)
        reload_current_page if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        @table_name
      end

      def add_stack_bar_chart_with_no_series_and_save_for(options = {})
        query = generate_stack_bar_chart_with_no_series_query(options)
        edit_overview_page
        paste_query_and_save(query)
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        @table_name
      end



      def generate_average_query(value, *condition_string)
        condition_string = condition_string.join(' AND ')
        query = %{
          average query: SELECT #{value} WHERE #{condition_string}
        }
        query
      end

      def print_plv_value(*plv_names)
        plv_names.each do|plv_name|
          query = %{project-variable name: #{plv_name}}
          paste_query(query)
        end
      end

      def generate_value_query(value_or_aggregate, *condition_string)
        condition_string = condition_string.join(' AND ')
        query = %{
          value query: SELECT #{value_or_aggregate} WHERE #{condition_string}
        }
        query
      end

      def generate_value_query_without_condition(value_or_aggregate)
        query = %{value query: SELECT #{value_or_aggregate}}
        query
      end

      def generate_table_query(select_options, conditions = [], options = {})
        @table_name = "table_query".uniquify
        condition_string = conditions.empty? ? '' : 'WHERE ' + conditions.join(' AND ')
        group_by_string = options[:group_by] ? "GROUP BY #{options[:group_by].join(',')}" : ''
        order_by_string = options[:order_by] ? "ORDER BY #{options[:order_by].join(',')}" : ''
        table_name = select_options.join('_')
        %{table query: SELECT #{select_options.join(",")} #{condition_string} #{order_by_string} #{group_by_string}}
      end

      def generate_table_query_for_cross_project(select_options, condition_string, cross_project, options = {})
        additional_text = options[:additional_text]
        cross_project = cross_project.identifier if cross_project.respond_to?(:identifier)
        @table_name = "table_query".uniquify
        condition_string = 'WHERE ' + condition_string.join(' AND ')
        condition_string = '' if(condition_string == 'WHERE ')
        table_name = select_options.join('_')
        %{
      table
         query: SELECT #{select_options.join(",")} #{condition_string}
         project: #{cross_project}
         #{additional_text}
       }
      end

      def generate_ratio_bar_chart(property, aggregate, options={})
        query_conditions = options[:query_conditions] || ''
        condition_string = 'WHERE ' + query_conditions
        condition_string = '' if(condition_string == 'WHERE ')
        restrict_conditions = options[:restrict_conditions] || ''
        cross_project_reporting = "project: #{options[:cross_project]}" if options[:cross_project]
      %{
          ratio-bar-chart
            totals: SELECT #{property}, #{aggregate} #{condition_string}
            restrict-ratio-with: #{restrict_conditions}
            render_as_text: #{options[:render_as_text] || 'false'}
            #{cross_project_reporting}
      }
      end

      def generate_pie_chart(property, aggregate, options={})
          condition_string = unless options[:conditions].blank?
            "WHERE #{options[:conditions]}" end
      %{
          pie-chart
           data: SELECT #{property}, #{aggregate} #{condition_string}
           render_as_text: #{options[:render_as_text] || 'false'}
      }
      end


      def generate_table_view_query(view_name)
        %{table view: #{view_name} }
      end

      def generate_data_series_chart_query(options={})
        @table_name = "data_series_chart".uniquify
        conditions = options[:conditions]
        chart_conditions = options[:chart_conditions]
        aggregate = options[:aggregate] || 'COUNT(*)'
        property = options[:property]
        x_labels_conditions = options[:x_labels_conditions] || ""
        x_labels_start = options[:x_labels_start] || ""
        x_labels_end = options[:x_labels_end] || ""
        x_labels_tree = options[:x_labels_tree] || ""
        series_type = options[:series_type] || "line"
        data_labels = options[:data_labels] || ""
        %{
         data-series-chart
            conditions: #{chart_conditions}
            cumulative: true
            x-labels-start: #{x_labels_start}
            x-labels-end: #{x_labels_end}
            x-labels-step:
            x-labels-conditions: #{x_labels_conditions}
            x-labels-tree: #{x_labels_tree}
            render_as_text: #{options[:render_as_text] || 'false'}
            series:
            - label: Series 1
              type: #{series_type}
              data: SELECT #{property}, #{aggregate} WHERE #{conditions}
              trend: false
              trend-line-width: 2
              data-labels: #{data_labels}
        }
      end


    # This is only for testing the syntax error of data series when there is no series parameter
        def generate_a_data_series_chart_with_no_series(options={})
          @table_name = "data_series_chart".uniquify
          conditions = options[:conditions]
          %{
           data-series-chart
              conditions: #{conditions}
              cumulative: true
              x-labels-start:
              x-labels-end:
              x-labels-step:
          }
        end

    #this method is invalid, it is only for testing the syntax error of data_series, and in this case, I delete one space on series level.
      def generate_a_incorrect_data_series_chart_query(options={})
        @table_name = "data_series_chart".uniquify
        conditions = options[:conditions]
        aggregate = options[:aggregate] || 'COUNT(*)'
        property = options[:property]
        %{
         data-series-chart
            conditions:
            cumulative: true
            x-labels-start:
            x-labels-end:
            x-labels-step:
            series:
            - label: Series 1
              type: line
              data:SELECT #{property}, #{aggregate} WHERE #{conditions}
              trend: true
              trend-line-width: 2
        }
      end

      def generate_stack_bar_chart_query(options={})
        @table_name = "stack_bar_chart".uniquify
        conditions = options[:conditions]
        aggregate = options[:aggregate] || 'COUNT(*)'
        property = options[:property]
        x_label_start = options[:x_label_start] || ""
        x_label_end = options[:x_label_end] || ""
        %{
          stack-bar-chart
            conditions:
            labels:
            cumulative:
            render_as_text: #{options[:render_as_text] || 'false'}
            x-label-start: #{x_label_start}
            x-label-end: #{x_label_end}
            x-label-step:
            series:
            - label: Series 1
              color: green
              type: bar
              data: SELECT #{property}, #{aggregate} WHERE #{conditions}
              combine: overlay-bottom
        }
      end

      def generate_stack_bar_chart_with_two_series_query(options={})
        @table_name = "stack_bar_chart".uniquify
        conditions = options[:conditions]
        data_1 = options[:data_1]
        data_2 = options[:data_2]
        label_1 = options[:label_1]
        label_2 = options[:label_2]
        %{
          stack-bar-chart
            conditions: #{conditions}
            labels:
            cumulative:
            render_as_text: #{options[:render_as_text] || 'false'}
            series:
            - label: #{label_1}
              color: red
              type: bar
              data: #{data_1}
              combine: overlay-bottom
            - label: #{label_2}
              color: black
              type: bar
              data: #{data_2}
              combine: total
        }

      end

      def generate_stack_bar_chart_with_no_series_query(options={})
        @table_name = "stack_bar_chart".uniquify
        conditions = options[:conditions]
        %{
          stack-bar-chart
            conditions: #{conditions}
            labels:
            cumulative:
            x-label-start:
            x-label-end:
            x-label-step:
        }
      end


      def generate_macro_content_for_data_series_chart_with_two_series(options={})
         content = %Q{
               data-series-chart
                  render_as_text: #{options[:render_as_text]}
                  conditions: #{options[:conditions]}
                  cumulative: #{options[:cumulative]}
                  x-labels-tree: #{options[:x_labels_tree]}
                  series:
                  - label: #{options[:label_1]}
                    project: #{options[:project_1]}
                    color: red
                    type: line
                    data: #{options[:data_query_1]}
                    down-from: #{options[:down_from_1]}
                  - label:  #{options[:label_2]}
                    project: #{options[:project_2]}
                    color: green
                    type: line
                    data: #{options[:data_query_2]}
                    down-from: #{options[:down_from_2]}}
      end

      def click_preview_tab
        @browser.with_ajax_wait do
          @browser.click(WikiPageId::PREVIEW_TAB_LINK_ID)
        end
      end

      def add_macro_parameters_for(chart_type, parameters)
        parameters.each do |para|
          add_macro_parameter_for(chart_type, para)
        end
      end

      def add_macro_parameter_for(chart_type,parameter)
        click_add_macro_parameter_icon_for(chart_type)
        @browser.with_ajax_wait do
          # @browser.wait_for_element_visible optional_parameter_chart_option_id(chart_type, parameter)
          @browser.click(optional_parameter_chart_option_id(chart_type, parameter))
        end
      end

      def click_add_macro_parameter_icon_for(chart_type)
        @browser.with_ajax_wait do
          @browser.click(add_optional_parameter_droplink(chart_type))
        end
        # sleep 1
      end

      def with_open_and_close_macro_parameter_droplist(chart_type, &block)
        click_add_macro_parameter_icon_for(chart_type)  # to open drop list
        yield
        click_add_macro_parameter_icon_for(chart_type)  # to close drop list
      end

      def remove_macro_parameter_for(macro_type, para)
        @browser.with_ajax_wait do
          @browser.wait_for_element_visible remove_optional_parameter_id(macro_type,para)
          @browser.click(remove_optional_parameter_id(macro_type,para))
        end
      end

      def remove_macro_parameters_for(macro_type, paras)
        paras.each do |para|
          remove_macro_parameter_for(macro_type, para)
        end
      end

      def add_chart_macro_series_level_parameter_for(chart_type,series_index,parameter)
        click_add_chart_macro_series_level_parameter_icon_for(chart_type,series_index)
        @browser.with_ajax_wait do
          @browser.click(series_level_optional_parameter_chart_option_id(chart_type,series_index,parameter))
        end
      end


      def add_chart_macro_series_level_parameters_for(chart_type,series_index,paras)
        paras.each do |para|
          add_chart_macro_series_level_parameter_for(chart_type,series_index,para)
        end
      end

      def click_add_chart_macro_series_level_parameter_icon_for(chart_type, index=0)
        @browser.wait_for_element_visible series_level_add_optional_parameter_droplink(chart_type,index)
        @browser.with_ajax_wait do
          @browser.click(series_level_add_optional_parameter_droplink(chart_type,index))
        end
      end

      def with_open_and_close_macro_series_parameter_droplist(chart_type, index=0, &block)
        click_add_chart_macro_series_level_parameter_icon_for(chart_type, index)  # to open drop list
        yield
        click_add_chart_macro_series_level_parameter_icon_for(chart_type, index)  # to close drop list
      end

      def remove_chart_macro_series(chart_type, index=0)
        @browser.with_ajax_wait do
          @browser.click(remove_series_id(chart_type,index))
        end
      end

      def add_chart_macro_series(chart_type, index, options)
        raise("You must pass the :expected_series_index_added option into add_chart_macro_series") unless options[:expected_series_index_added]
        @browser.with_ajax_wait do
          @browser.click(add_series_id(chart_type,index))
        end
        @browser.wait_for_element_visible(series_container_id(chart_type,options))
      end

      def remove_chart_macro_series_level_parameters(chart_type, chart_series, paras)
        paras.each do |para|
          remove_chart_macro_series_level_parameter(chart_type, chart_series, para)
        end
      end

      def remove_chart_macro_series_level_parameter(chart_type, chart_series, para)
        remove_chart_macro_series_level_parameter_by_id(series_parameter_container_id(chart_type,chart_series,para))
      end

      def remove_chart_macro_series_level_parameter_by_id(parameter_id)
        @browser.with_ajax_wait do
          @browser.click(remove_chart_macro_series_level_id(parameter_id))
        end
      end

      def add_pie_chart_and_save_for(property, aggregate, options={})
        query = generate_pie_chart(property, aggregate, options)
        paste_query_and_save(query)
        reload_current_page  if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
      end

      def add_ratio_bar_chart_and_save_for(property, aggregate, options={})
        query = generate_ratio_bar_chart(property, aggregate, options)
        paste_query_and_save(query)
        reload_current_page if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        "ratio-bar-chart-#{property.gsub("\s", '-')}"
      end

      def add_data_series_chart_and_save_for(options = {})
        query = generate_macro_content_for_data_series_chart_with_two_series(options)
        paste_query_and_save(query)
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
      end

      def add_daily_history_chart_and_save(query)
        with_ajax_wait { paste_query_and_save(query) }
        DailyHistoryChart.process(:batch_size => 6)
        sleep 4
        with_ajax_wait { reload_current_page }
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK)
      end

      def add_google_maps_macro_and_saved_on(options={})
        query = generate_google_maps_macro(options)
        paste_query_and_save(query)
        reload_current_page if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        @macro_name
      end

      def add_google_calendar_macro_and_saved_on(options={})
        query = generate_google_calendar_macro(options)
        paste_query_and_save(query)
        reload_current_page if options[:render_as_text]
        click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK) if options[:render_as_text]
        @macro_name
      end

      def generate_google_maps_macro(options={})
        @macro_name = "google_maps".uniquify
        src = options[:src]
        heigth = options[:heigth]
        width = options[:width]
        %{
          google-maps
          src: #{src}
          heigth: #{heigth}
          width: #{width}
        }
      end

      def generate_google_calendar_macro(options={})
        @macro_name = "google_calendar".uniquify
        src = options[:src]
        heigth = options[:heigth]
        width = options[:width]
        %{
          google-calendar
          src: #{src}
          heigth: #{heigth}
          width: #{width}
        }
      end

    def paste_query_and_save(query)
        create_free_hand_macro(query)
        if @browser.is_element_present(WikiPageId::SAVE_BUTTON_ID)
          if !@browser.is_element_present(class_locator("error"))
            save_card
            @browser.wait_for_element_present("css=#notice")
          end
        else
          if !@browser.is_element_present(class_locator("error"))
            click_save_link
            @browser.wait_for_element_present("css=#notice")
          end
        end
    end

    def paste_query(query)
      @browser.wait_for_element_visible class_locator("cke_toolbox")
      create_free_hand_macro(query)
    end



    def add_pivot_table_query_and_save_for(row_property, column_property, options={})
        query = generate_pivot_table_query(row_property, column_property, options)
        paste_query_and_save(query)
        "pivot-table-#{row_property}-#{column_property}"
    end

    def generate_pivot_table_query(row_property, column_property, options={})
        conditions = options[:conditions]
        aggregation = options[:aggregation] || 'COUNT(*)'
        empty_columns = options[:empty_columns] || true
        empty_rows = options[:empty_rows] || true
        links = options[:links] || true
        totals = options[:totals] || false
        id = options[:id] || "pivot-table-#{row_property}-#{column_property}"
        %{
            pivot-table:
            conditions: #{conditions}
            aggregation: #{aggregation}
            rows: #{row_property}
            columns: #{column_property}
            empty-rows: #{empty_rows}
            empty-columns: #{empty_columns}
            links: #{links}
            totals: #{totals}
        }
    end

end


module WikiPageAction
    include ChartGeneratorAction



    def open_wiki_page(project, wiki_page)
        project= project.identifier if project.respond_to? :identifier
        @browser.open "/projects/#{project}/wiki/#{wiki_page}"
        @browser.wait_for_all_ajax_finished
    end

    def create_new_wiki_page_via_model(project, page_name, content)
      project.pages.create!(:name => page_name, :content => content)
    end

    def click_edit_link_on_wiki_page
        @browser.click_and_wait(WikiPageId::EDIT_WIKI_PAGE_LINK)
        wait_for_wysiwyg_editor_ready
    end

    def click_go_back_link_on_warning_bar_of_expired_wiki_contents
        @browser.click_and_wait(WikiPageId::BACK_WIKI_PAGE_LINK)
    end

    def click_latest_version_link_on_warning_bar_of_expired_wiki_contents
        @browser.click_and_wait(WikiPageId::LATEST_VERSION_WIKI_PAGE_LINK)
    end

    def create_overview_page
        @browser.click_and_wait(WikiPageId::WHY_NOT_CREATE_WIKI_PAGE_LINK)
    end

    def create_new_overview_page_with_content_for(project, content)
        location = @browser.get_location
        navigate_to_project_overview_page(project) unless location =~ /#{project.identifier}\/wiki\/Overview_Page/
        add_content_to_wiki(content)
    end

    def edit_overview_page_with(content)
        edit_overview_page
        type_page_content(content)
        @browser.click_and_wait(WikiPageId::SAVE_LINK_ON_WIKI)
    end

    def create_new_wiki_page(project, page_name, contents)
        open_new_wiki_page_for_edit(project, page_name)
        wait_for_wysiwyg_editor_ready
        type_page_content(contents)
        @browser.click_and_wait(WikiPageId::SAVE_LINK_ON_WIKI)
    end

    def type_page_content(text)
        enter_text_in_editor(text)
    end

    def open_wiki_page_for_edit(project, wiki_page)
        project = project.identifier if project.respond_to?(:identifier)
        open_wiki_page(project, wiki_page)
        @browser.wait_for_element_visible WikiPageId::EDIT_WIKI_PAGE_LINK
        @browser.click_and_wait(WikiPageId::EDIT_WIKI_PAGE_LINK)
    end


    def click_overview_tab
        click_tab("Overview")
    end

    def edit_overview_page
      click_tab("Overview")
      if @browser.is_element_present(WikiPageId::WHY_NOT_CREATE_WIKI_PAGE_LINK)
        @browser.click_and_wait(WikiPageId::WHY_NOT_CREATE_WIKI_PAGE_LINK)
      elsif @browser.is_element_present(WikiPageId::EDIT_WIKI_PAGE_LINK)
        @browser.click_and_wait(WikiPageId::EDIT_WIKI_PAGE_LINK)
      else
        sleep 0.1
        return edit_overview_page
      end
      wait_for_wysiwyg_editor_ready
    end

    def navigate_to_project_overview_page(project)
        @browser.open("/projects/#{project.identifier}")
    end



    def open_overview_page_for_edit(project)
        location = @browser.get_location
        navigate_to_project_overview_page(project) unless location =~ /#{project.identifier}\/wiki\/Overview_Page/
        @browser.click_and_wait(WikiPageId::WHY_NOT_CREATE_WIKI_PAGE_LINK) if !@browser.is_element_present(WikiPageId::EDIT_PAGE_CONTENT_ID)
    end

    def open_page_version(project, page_name, options)
        project = project.identifier if project.respond_to? :identifier
        version = options[:version]
        @browser.open("/projects/#{project}/wiki/#{page_name}?version=#{version}")
    end

    def add_content_to_wiki(content)
        @browser.click_and_wait(WikiPageId::WHY_NOT_CREATE_WIKI_PAGE_LINK) if !@browser.is_element_present(WikiPageId::EDIT_PAGE_CONTENT_ID)
        enter_text_in_editor(content)
        click_save_link
    end

    def load_page_history
        @browser.run_once_history_generation
        if @browser.is_element_present(WikiPageId::EXPAND_HISTORY_ID) &&
            (@browser.get_eval("this.browserbot.getCurrentWindow().$('history_collapsible_content').loaded") == 'null')
            @browser.with_ajax_wait{@browser.click WikiPageId::EXPAND_HISTORY_ID}
        end
        if @browser.is_element_present(CardShowPageId::REFRESH_LINK_ID_ON_CARD)
            @browser.with_ajax_wait do
                @browser.click(CardShowPageId::REFRESH_LINK_ID_ON_CARD)
            end
        end
    end

    def click_history_on_page
        @browser.with_ajax_wait do
            @browser.click(WikiPageId::EXPAND_HISTORY_ID)
        end
    end

    def wait_for_page_history
        @browser.wait_for_element_not_visible(WikiPageId::HISTORY_SPINNER_ID)
    end

    def open_new_wiki_page_for_edit(project, page_name)
        project = project.identifier if project.respond_to?(:identifier)
        @browser.open("/projects/#{project}/wiki/#{page_name}")
    end

    def edit_page(project, page_name, contents = nil)
        open_wiki_page_for_edit(project, page_name)
        type_page_content(contents) if contents
        click_save_link
    end

    def click_on_wiki_page_link_for(link)
        @browser.click_and_wait("link=#{link}")
    end

    def click_and_add_content_to_wiki_page(link, content)
        click_on_wiki_page_link_for(link)
        add_content_to_wiki(content)
    end

    def click_on_card_link_on_wiki_page(card)
        @browser.click_and_wait("link=##{card.number}")
    end

    def preview_wiki_content
        @browser.with_ajax_wait do
            @browser.click WikiPageId::PREVIEW_TAB_LINK_ID
        end
    end

    def create_special_header_for_creating_new_card(project, type_name)
        contents =  %{<a href="\/projects\/#{project.identifier}\/cards\/new?properties[Type]=#{type_name}" accesskey="D"> +#{type_name}</a>}
        create_new_wiki_page(project, 'Special:HeaderActions', contents)
    end

    def click_remove_from_favorites_through_wiki_page(project, wiki_def)
        open_wiki_page(project, wiki_def.name)
        @browser.assert_element_present(remove_from_favorite_link)
        @browser.with_ajax_wait do
            @browser.click(remove_from_favorite_link)
        end
    end

    def click_remove_from_tabs_through_wiki_page(project, wiki_def)
        open_wiki_page(project, wiki_def.name)
        title = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('top_tab_link').title")
        if title == 'Remove tab'
            @browser.with_ajax_wait do
                @browser.click(WikiPageId::REMOVE_TAB_LINK)
            end
        else
            raise "The '#{wiki_def.name}' wiki is not a Tab yet..."
        end
    end

    def make_wiki_as_tab_for(project, wiki_def)
        # open_wiki_page(project, wiki_def.name)
        title = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('top_tab_link').title")
        if title == 'Make tab'
            click_link_with_ajax_wait(WikiPageId::MAKE_TAB_ID)
        else
            raise "The '#{wiki_def.name}' wiki is already a tab..."
        end
    end

    def make_wiki_as_favorite_for(project, wiki_def)
        # open_wiki_page(project, wiki_def.name)
        title = @browser.get_eval("this.browserbot.getCurrentWindow().document.getElementById('top_favorite_link').title")

        if title == 'Make team favorite'
            click_link_with_ajax_wait(WikiPageId::MAKE_TEAM_FAVORITE_ID)
        else
            raise "The #{wiki_def.name} is already a favorite..."
        end
    end

    def create_a_wiki_page_with_text(project, name, content)
        @browser.open("/projects/#{project.identifier}/wiki/#{name}")
        enter_text_in_editor(content)
        click_save_link
        assert_notice_message('Page was successfully created.')
        project.pages.find_by_name(name)
    end

    def create_wiki_page_as_favorite(project, name, content)
        wiki_page = create_a_wiki_page_with_text(project, name, content)
        open_wiki_page(project, wiki_page.name)
        make_wiki_as_favorite_for(project, wiki_page)
        wiki_page
    end

    def click_page_link(page_number)
        @browser.click_and_wait("page_#{page_number}")
    end

    def go_to_page(project, page_number, tab="All")
        project = project.identifier if project.respond_to? :identifier
        @browser.open("/projects/#{project}/cards/list?page=#{page_number}&style=list&tab=#{tab}")
    end

    def navigate_to_all_wikis_page(project)
        @browser.open("/projects/#{project.identifier}/wiki/list")
      end

end
