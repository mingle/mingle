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

module ProjectVariableAdminAction

    def navigate_to_project_variable_management_page_for(project)
        project = project.identifier if project.respond_to? :identifier
        @browser.open("/projects/#{project}/project_variables/list")
    end

    def plv_display_name(project_variable)
        project_variable = project_variable.name if project_variable.respond_to?(:name)
        "(#{project_variable})"
    end

    # the following 4 methods are for create different kind of PlVs in backgroud
    def create_text_plv(project, name, value, related_properties)
        property_ids = related_properties.collect {|property| property.id}
        create_plv!(project, :name => name, :data_type => ProjectVariable::STRING_DATA_TYPE, :value => value, :property_definition_ids => property_ids)
    end

    def create_number_plv(project, name, value, related_properties)
        property_ids = related_properties.collect{|property| property.id}
        create_plv!(project, :name => name, :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => value, :property_definition_ids => property_ids) 
    end

    def create_date_plv(project, name, value, related_properties)
        property_ids = related_properties.collect{|property| property.id}
        create_plv!(@project, :name => name, :data_type => ProjectVariable::DATE_DATA_TYPE, :value => value, :property_definition_ids => property_ids)
    end

    def create_card_plv(project, name, target_card_type, target_card, related_properties)
        property_ids = related_properties.collect{|property| property.id}
        target_card_id = target_card.id
        create_plv!(project, :name => name, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => target_card_type, :value => target_card_id, :property_definition_ids => property_ids)
    end

    def create_user_plv(project, name, value, related_properties)
        property_ids = related_properties.collect{|property| property.id}
        user_id = value.id
        create_plv!(project, :name => name, :data_type => ProjectVariable::USER_DATA_TYPE, :value => user_id, :property_definition_ids => property_ids)
    end

    def create_project_variable(project, options)
        project_variable_name = options[:name] || ''
        data_type = options[:data_type]
        card_type = options[:card_type]
        open_project_variable_create_page_for(project)
        type_project_variable_name(project_variable_name)
        select_data_type(data_type) if data_type
        select_card_type(project, card_type) if card_type && data_type == ProjectVariable::CARD_DATA_TYPE
        set_value(data_type, options[:value]) if options[:value]
        properties = options[:properties]
        select_properties_that_will_use_variable(project, *properties) if properties
        click_create_project_variable
        project.project_variables.find_by_name(project_variable_name)
    end

    def edit_project_variable(project, project_variable, options)
        open_project_variable_for_edit(project, project_variable)
        type_project_variable_name(options[:new_name]) if options[:new_name]
        data_type = if options[:new_data_type]
            select_data_type(options[:new_data_type])
            options[:new_data_type]
        # else
          # @browser.get_eval("this.browserbot.getCurrentWindow().$$('input[id^=project_variable_data_type_]:checked').value")
        end
        data_type = options[:data_type] if options[:data_type]
        set_value(data_type, options[:new_value]) if options[:new_value]
        uncheck_properties_that_will_use_variable(project, *options[:property_to_be_unchecked]) if options[:property_to_be_unchecked]
        select_properties_that_will_use_variable(project, *options[:property_to_be_checked]) if options[:property_to_be_checked]
        click_save_project_variable
    end

    def disassociate_project_variable_from_property(project, project_variable_name, *property_names)
        edit_project_variable(project, project.project_variables.find_by_name(project_variable_name), :property_to_be_unchecked => property_names)    
    end

    def associate_project_varible_from_property(project, project_variable_name, *property_names)    
        edit_project_variable(project, project.project_variables.find_by_name(project_variable_name), :property_to_be_checked => property_names)    
    end

    def rename_project_varible(project, project_variable, new_name)
        edit_project_variable(project, project.project_variables.find_by_name(project_variable), :new_name => new_name)    
    end

    def type_project_variable_name(project_variable_name)
        @browser.type(ProjectVariableAdminPageId::PROJECT_VARIABLE_NAME_ID, project_variable_name)
    end

    def type_project_variable_value(project_variable_value)
        @browser.type(ProjectVariableAdminPageId::PROJECT_VARIABLE_VALUE_ID, project_variable_value)
    end

    def select_data_type(data_type)
        @browser.with_ajax_wait do 
            @browser.click(project_variable_data_type_radio_button(data_type))
        end
    end

    def select_card_type(project, card_type)
        project = project.identifier if project.respond_to? :identifier
        if card_type == "Any card type"
            @browser.with_ajax_wait do
                @browser.click(ProjectVariableAdminPageId::ANY_CARD_TYPE_RADIO_BUTTON)
            end
        else
            card_type = Project.find_by_identifier(project).card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
            @browser.with_ajax_wait do
                @browser.click(card_type_radio_button(card_type))
            end
        end
    end

    def set_value(data_type, value)
        if(data_type == ProjectVariable::STRING_DATA_TYPE || data_type == ProjectVariable::NUMERIC_DATA_TYPE)
            type_project_variable_value(value)
        elsif(data_type == ProjectVariable::USER_DATA_TYPE)
            @browser.click(ProjectVariableAdminPageId::PROJECT_VARIABLE_DROP_LINK)
            @browser.click(project_variable_options(value))
        elsif(data_type == ProjectVariable::DATE_DATA_TYPE)
            @browser.click(ProjectVariableAdminPageId::PROJECT_VARIABLE_EDIT_LINK)
            @browser.type(ProjectVariableAdminPageId::PROJECT_VARIABLE_EDITOR_ID, value)
            @browser.press_enter(ProjectVariableAdminPageId::PROJECT_VARIABLE_EDITOR_ID)
        elsif(data_type == ProjectVariable::CARD_DATA_TYPE)
            open_value_selection_box_for_card_type
            @browser.click(card_selector_result_locator(:filter, value.number))
        end
    end

    def open_value_selection_box_for_card_type
        @browser.click(ProjectVariableAdminPageId::EDIT_PROJECT_VALUE_DROP_LINK)
        @browser.with_ajax_wait do
            @browser.click droplist_select_card_action(ProjectVariableAdminPageId::EDIT_PROJECT_VALUE_DROP_DOWN)
        end
    end

    def select_properties_that_will_use_variable(project, *properties)
        project = project.identifier if project.respond_to? :identifier
        properties.each do |property|    
            property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property, :with_hidden => true)
            @browser.click(property_definitions_check_box(property_definition))
        end
    end

    def uncheck_properties_that_will_use_variable(project, *properties)
        project = project.identifier if project.respond_to? :identifier
        properties.each do |property|
            property_definition = Project.find_by_identifier(project).find_property_definition_or_nil(property)
            property_check_box_id = property_definitions_check_box(property_definition)
            @browser.click(property_check_box_id) if @browser.is_checked(property_check_box_id)
        end
    end

    def open_project_variable_create_page_for(project)
        project = project.identifier if project.respond_to? :identifier
        @browser.open("/projects/#{project}/project_variables/new")
    end

    def open_project_variable_for_edit(project, project_variable)
        project = project.identifier if project.respond_to? :identifier
        project_variable = Project.find_by_identifier(project).project_variables.find_by_name(project_variable) unless project_variable.respond_to? :name
        @browser.open("/projects/#{project}/project_variables/edit/#{project_variable.id}")
    end

    def delete_project_variable(project, project_variable_name)
        location = @browser.get_location
        navigate_to_project_variable_management_page_for(project) unless location =~ /#{project.identifier}\/project_variables\/list/
        project = project.identifier if project.respond_to? :identifier
        project_variable_definition = Project.find_by_identifier(project).project_variables.find_by_name(project_variable_name)
        @browser.click_and_wait(project_variable_delete_link(project_variable_definition))
    end

    def delete_project_variable_permanently(project, project_variable_name)
        project = project.identifier if project.respond_to? :identifier
        project_variable_definition = Project.find_by_identifier(project).project_variables.find_by_name(project_variable_name)
        @browser.click_and_wait(project_variable_delete_link(project_variable_definition))
        click_on_continue_to_delete_link
    end

    def click_on_continue_to_delete_link
        @browser.click_and_wait(ProjectVariableAdminPageId::CONTINUE_TO_DELETE_LINK)
    end

    def click_on_continue_to_update
        @browser.click_and_wait(ProjectVariableAdminPageId::CONTINUE_TO_UPDATE_LINK)
    end

    def click_create_new_project_variable
        @browser.click_and_wait(ProjectVariableAdminPageId::CREATE_NEW_PROJECT_VARIABLE_LINK)
    end

    def click_create_project_variable
        @browser.click_and_wait(ProjectVariableAdminPageId::CREATE_PROJECT_VARIABLE_LINK)
    end

    def click_save_project_variable
        @browser.click_and_wait(ProjectVariableAdminPageId::SAVE_PROJECT_VARIABLE_LINK)
    end
end
