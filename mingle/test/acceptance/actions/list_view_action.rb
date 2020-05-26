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

module ListViewAction
    NULL_VALUE = '(not set)'

    def navigate_to_a_card_view(view_type, options={})
        tree_name = options[:tree_name]
        @browser.open("/projects/#{@project.identifier}/cards/#{view_type}?&tab=All&tree_name=#{tree_name}") if tree_name
        @browser.open("/projects/#{@project.identifier}/cards/#{view_type}?page=1&tab=All") unless tree_name
        @browser.wait_for_all_ajax_finished
    end

    def navigate_to_list_view_for(project, tree)
        @browser.open("/projects/#{project.identifier}/cards/list?tree_name=#{tree.name}")
    end

    def switch_to_list_view
      @browser.click_and_wait ListViewPageId::LIST_VIEW_LINK
    end

    def navigate_to_card_list_showing_iteration_and_status_for(project, tab='All')
        project = project.identifier if project.respond_to? :identifier
        @browser.open "/projects/#{project}/cards/list?tab=#{tab}&columns=iteration,status"
    end

    def select_all
        @browser.click ListViewPageId::SELECT_ALL_ID
    end

    def click_edit_properties_button
        @browser.with_ajax_wait(30000) do
            @browser.click ListViewPageId::BULK_SET_PROPERTIES_BUTTON
        end
    end

    def add_new_value_to_property_on_bulk_edit(project, property, value)
        project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
        project.reload.with_active_project do |active_project|
            property = active_project.reload.find_property_definition(property, :with_hidden => true)
            property_type = property.attributes['type']
            if(property_type == 'EnumeratedPropertyDefinition')
                add_value_to_property_using_inline_editor('bulk', property, value, true)
                @browser.run_once_history_generation
            elsif(property_type == 'DatePropertyDefinition' || property_type == 'TextPropertyDefinition')
                add_value_to_date_or_free_text_property_using_droplist_inline_editor('bulk', property, value, true)
                @browser.run_once_history_generation
            else
                raise "Property type #{property_type} is not supported"
            end
        end
    end

    def navigate_to_card_list_for(project, columns = [], tab="All")
        project = project.identifier if project.respond_to? :identifier
        base_url = "/projects/#{project}/cards"
        query_params = []
        query_params << "columns=#{columns.join(',')}" if columns.size > 0
        query_params << "tab=#{tab}"
        @browser.open "#{base_url}/list?#{query_params.join('&')}"
        @browser.wait_for_all_ajax_finished
    end

    def navigate_to_card_list_by_clicking(project)
        open_project(project)
        click_all_tab
    end


    def add_column_for(project, property_defs)
        @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
        property_defs.each do |property_def|
            @browser.with_ajax_wait do
                @browser.click toggle_column_id(project,property_def)
                @browser.click ListViewPageId::APPLY_TO_SELECTED_COLUMN_ID
            end
        end
    end

    def remove_column_for(project, property_defs)
        @browser.click 'link=Add / remove columns'
        property_defs.each do |property_def|
            @browser.with_ajax_wait do
                @browser.click toggle_column_id(project,property_def)
                @browser.click ListViewPageId::APPLY_TO_SELECTED_COLUMN_ID
            end
        end
    end

    def really_select_all_cards(number_of_cards)
        @browser.click select_all_cards_id(number_of_cards)
    end

    def select_none
        @browser.click ListViewPageId::SELECT_NONE_ID
    end

    def open_bulk_edit_properties
        click_edit_properties_button unless @browser.is_visible ListViewPageId::BULK_SET_PROPERTIES_PANEL
    end

    def open_bulk_transitions
        @browser.with_ajax_wait do
            @browser.click ListViewPageId::BULK_TRANSITION_ID
        end
    end

    def click_bulk_delete_button
      sleep 1
      counter = 0
        @browser.with_ajax_wait(30000) do
            begin
              @browser.click ListViewPageId::BULK_DELETE_ID
              counter = counter + 1
            end while (@browser.get_eval("this.browserbot.getCurrentWindow().$('#{ListViewPageId::BULK_DELETE_ID}').disabled") == 'false') && !(@browser.is_element_present(warning_box_id)) && counter <=50
        end
        if counter >= 50
          p "failed to click on Delete..."
        end
    end

    def click_confirm_bulk_delete
        @browser.click_and_wait ListViewPageId::CONFIRM_DELETE_ID
    end

    def click_bulk_tag_button
        @browser.with_ajax_wait(30000) do
            @browser.click ListViewPageId::BULK_TAGS_BUTTON
        end
    end

    def bulk_tag_with(*tags)
        @browser.type ListViewPageId::BULK_TAGS_TEXT_BOX, tags.join(',')
        @browser.with_ajax_wait(120000) do
            @browser.click ListViewPageId::SUBMIT_BULK_TAGS_ID
        end
    end

    def bulk_tag(*tags)
        click_bulk_tag_button
        bulk_tag_with(tags)
    end

    def bulk_remove_tag(*tag_names)
        tag_names.each do |tag_name|
            tag_id = @project.tags.find_by_name(tag_name).id
            @browser.with_ajax_wait(120000) do
                @browser.click remove_tag_id(tag_id)
            end
        end
        update_history_and_search_cache_tables
    end

    def set_card_type_on_bulk_edit(card_type)
        @browser.with_ajax_wait do
            @browser.click ListViewPageId::BULK_EDIT_CARD_TYPE_LINK
            @browser.click bulk_edit_card_type_option(card_type)
            @browser.click ListViewPageId::CONTINUE_BUTTON
        end
        update_history_and_search_cache_tables
    end

    def set_bulk_property(property, value)
        @browser.click droplist_link_id(property, 'bulk')
        @browser.with_ajax_wait do
            value = NULL_VALUE if value.nil?
            @browser.click droplist_option_id(property, value, 'bulk')
        end
    end

    def set_bulk_properties(project, properties)
        properties = values_by_property_definition(project, properties)
        properties.each do |property, value|
            value = NULL_VALUE if value.nil?
            property_type = property.is_a?(CardTypeDefinition) ? 'CardTypeDefinition' : property.attributes['type']
            if need_popup_card_selector?(property_type, value)
                @browser.click bulk_edit_property_drop_link(property)
                @browser.with_ajax_wait do
                    @browser.click droplist_select_card_action(bulk_edit_property_drop_down(property))
                end
                card_number = value.respond_to?(:number) ? value.number : value
                @browser.with_ajax_wait do
                    @browser.click card_selector_result_locator(:filter, card_number)
                end
            elsif(property_type == 'CardTypeDefinition')
                set_card_type_on_bulk_edit(value)
            else
                set_bulk_property(property, value)
            end
        end
        update_history_and_search_cache_tables
    end

    def add_value_to_property_using_inline_editor_on_bulk_edit(property, value, ajaxy = true)
        add_value_to_property_using_inline_editor('bulk', property, value, ajaxy)
        @browser.run_once_history_generation
    end

    def add_value_to_date_property_using_inline_editor_on_bulk_edit(property, value, ajaxy = true)
        add_value_to_date_or_free_text_property_using_droplist_inline_editor('bulk', property, value, ajaxy)
        @browser.run_once_history_generation
    end

    def add_value_to_free_text_property_using_inline_editor_on_bulk_edit(property, value, ajaxy = true)
        add_value_to_date_or_free_text_property_using_inline_editor('bulk', property, value, ajaxy)
        @browser.run_once_history_generation
    end

    def wait_for_list_view
      @browser.wait_for_element_present('card_list_view')
    end

    def execute_bulk_transition_action(transition)
        open_bulk_transitions
        @browser.with_ajax_wait do
            @browser.click_and_wait list_transition_link(transition)
        end
        update_history_and_search_cache_tables
    end

    def execute_bulk_transition_action_that_requires_input(transition)
        open_bulk_transitions
        @browser.with_ajax_wait do
            @browser.click list_transition_link(transition)
        end
        update_history_and_search_cache_tables
    end

    def type_keyword_to_search_value_for_property_on_bulk_edit_panel(property, keyword)
        @browser.type_in_property_search_filter(bulk_drop_list_drop_down_id(property), keyword)
    end

    def select_value_in_drop_down_for_property_on_bulk_edit_panel(property,value)
        @browser.with_ajax_wait do
            value = NULL_VALUE if value.nil?
            @browser.click droplist_option_id(property, value, 'bulk')
        end
    end

    def click_property_on_bulk_edit_panel(property)
        @browser.assert_visible droplist_link_id(property, 'bulk')
        @browser.click droplist_link_id(property, 'bulk')
    end

    def click_cancle_bulk_edit_card_type
        @browser.with_ajax_wait do
            @browser.click ListViewPageId::CANCEL_BUTTON
        end
    end

    def select_card_type_on_bulk_edit(card_type)
        @browser.with_ajax_wait do
            @browser.click ListViewPageId::BULK_EDIT_CARD_TYPE_LINK
            @browser.click bulk_edit_card_type_option(card_type)
        end
    end

    def select_cards(cards)
        cards.each do |card|
            @browser.with_ajax_wait do
                @browser.click select_card_id(card)
            end
        end
    end

    def click_card_on_list(card)
        card = card.number if card.respond_to? :number
        @browser.with_ajax_wait do
            @browser.click_and_wait card_on_list_id(card)
        end
    end

    def sort_by(property)
        click_card_list_column_and_wait("#{property}")
    end

    def click_card_list_column_and_wait(name)
        @browser.with_ajax_wait do
            @browser.click card_list_column_id(name)
        end
    end

    def sort_by_column_number(position)
        @browser.with_ajax_wait do
            @browser.click(column_header_link(position))
        end
    end

    def check_cards_in_list_view(*cards)
        cards.each { |card| check_card_in_list_view(card) }
    end

    def uncheck_cards_in_list_view(*cards)
        cards.each { |card| uncheck_card_in_list_view(card) }
    end

    def check_card_in_list_view(card)
        checkbox_id = get_card_checkbox_id(card)
        unless (@browser.is_checked(checkbox_id))
            @browser.click(get_card_checkbox_id(card))
        end
    end

    def uncheck_card_in_list_view(card)
        checkbox_id = get_card_checkbox_id(card)
        if (@browser.is_checked(checkbox_id))
            @browser.click(get_card_checkbox_id(card))
        end
    end

    def get_card_checkbox_id(card)
        checkbox_id = @browser.get_eval(%{
            this.browserbot.getCurrentWindow().$('#{card.html_id}').down().down().id;
            })
            checkbox_id
        end

        def click_checkbox_of_column(project,columns)
            columns.each do |column|
                @browser.click toggle_column_id(project,column)
            end
        end

        def click_add_or_remove_columns_link
            @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
        end

        def add_all_columns
            @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
            @browser.with_ajax_wait do
                @browser.click ListViewPageId::SELECT_ALL_LANES_ID if @browser.is_not_checked(ListViewPageId::SELECT_ALL_LANES_ID)
                @browser.click ListViewPageId::APPLY_TO_SELECTED_COLUMN_ID
            end
        end

        def remove_all_columns
            @browser.click ListViewPageId::ADD_OR_REMOVE_COLUMNS_LINK
            @browser.with_ajax_wait do
                @browser.click(ListViewPageId::SELECT_ALL_LANES_ID) if @browser.is_checked(ListViewPageId::SELECT_ALL_LANES_ID)
                @browser.click ListViewPageId::APPLY_TO_SELECTED_COLUMN_ID
            end
        end

        def open_card_from_list(card)
            click_link(card.name)
        end


        def navigate_to_view_for(project, view_as='list', options={})
            project = project.identifier if project.respond_to? :identifier
            url = "/projects/#{project}/cards/#{view_as}"
            url += '?' + options.collect { |name, value| "#{name}=#{value.gsub(/ /, '+')}" }.join('&') if options.any?
            @browser.open url
        end



        private
        def update_history_and_search_cache_tables
            @browser.run_once_history_generation
        end

    end
