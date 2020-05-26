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

module ProjectCreateUpdateSettingsAction

    def navigate_to_project_admin_for(project)
      project = project.identifier if project.respond_to? :identifier
      @browser.open "/projects/#{project}"
      click_project_admin_link
    end

    def go_to_export_project_page(project)
      @browser.open("/projects/#{project.identifier}/project_exports/confirm_as_project")
    end

    def go_to_export_project_as_template_page(project)
      @browser.open("/projects/#{project.identifier}/project_exports/confirm_as_template")
    end

    def create_new_project(name, options = {})
      navigate_to_all_projects_page
      email_sender_name = options[:email_sender_name] || ''
      email_address = options[:email_address] || ''
      template_name = options[:template_identifier] || ProjectsController::BLANK

      navigate_to_all_projects_page
      if @browser.is_element_present ProjectCreateUpdateSettingsPageId::NEW_PROJECT_LINK
        click_new_project_link
      else
        @browser.click_and_wait ProjectCreateUpdateSettingsPageId::WHY_NOT_CREATE_LINK
      end
      type_project_name(name)
      select_template(template_name, options[:template_origin])
      select_date_format(options[:date_format]) if options[:date_format]
      @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_EMAIL_SENDER_NAME_ID, email_sender_name)
      @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_EMAIL_ADDRESS_ID, email_address)
      @browser.click ProjectCreateUpdateSettingsPageId::AS_MEMBER_ID if options[:as_member] == false
      click_create_project_button
      Project.find_by_name(name)
    end

    def set_project_date_format(date_format)
        click_show_advanced_options_link
        select_date_format(date_format)
        click_save_link
    end

    def set_project_time_zone(time_zone)
        click_show_advanced_options_link
        @browser.select(ProjectCreateUpdateSettingsPageId::PROJECT_TIME_ZONE_DROPDOWN, time_zone)
        click_save_link
    end

    def select_date_format(date_format)
        @browser.select(ProjectCreateUpdateSettingsPageId::PROJECT_DATE_FORMAT_DROPDOWN, date_format)
    end

    def click_project_admin_link
        @browser.click_and_wait ProjectCreateUpdateSettingsPageId::PROJECT_ADMIN_LINK
    end

    def open_project_admin_for(project)
        project = project.identifier if project.respond_to? :identifier
        @browser.open "/projects/#{project}"
        click_project_admin_link
    end

    def click_project_admin_menu_link_for(menu_item)
        @browser.click_and_wait(project_admin_link_for(menu_item))
    end

    def update_project_settings_with(project,options={})
        navigate_to_project_admin_for(project)
        click_show_advanced_options_link
        set_options(options)
        @browser.click_and_wait(ProjectCreateUpdateSettingsPageId::PROJECT_SAVE_LINK)
    end

    def open_admin_edit_page_for(project)
        @browser.open("/projects/#{project.identifier}/admin/edit")
    end

    def type_project_identifier(project_identiifer)
        @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_IDENTIFIER_NAME, project_identiifer)
    end

    def type_project_name(name)
        @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_NAME_ID, name)
    end

    def type_project_description(project_description)
        @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_DESCRIPTION_NAME, project_description)
    end

    def click_show_advanced_options_link
        @browser.click(ProjectCreateUpdateSettingsPageId::ADVANCED_OPTIONS_LINK)
    end

    def select_template(template_identifier, origin = nil)
      @browser.click(template_name_identifier(template_identifier, origin))
    end

    def create_a_projct_with_membership_requestable_checked(project_name)
        type_project_name(project_name)
        @browser.check(ProjectCreateUpdateSettingsPageId::PROJECT_MEMBERSHIP_REQUESTABLE_ID)
        click_create_project_button
    end

    def create_project_from_current_project_template(new_project_name,current_project)
        type_project_name(new_project_name)
        @browser.click(template_name_from_current_project_name(current_project))
        click_create_project_button
    end

    def create_a_project_with_membership_requstable_and_anon_accessible_checked(project_name)
        type_project_name(project_name)
        @browser.check(ProjectCreateUpdateSettingsPageId::PROJECT_MEMBERSHIP_REQUESTABLE_ID)
        @browser.check(ProjectCreateUpdateSettingsPageId::PROJECT_ANONYMOUS_ACCESSIBLE_ID)
        click_create_project_button
    end

    def create_a_project_with(options={})
        navigate_to_all_projects_page
        click_new_project_link
        click_show_advanced_options_link
        set_options(options)
        click_create_project_button
    end


    def click_create_project_button
        @browser.click_and_wait ProjectCreateUpdateSettingsPageId::CREATE_PROJECT_LINK
    end

    def click_cancel_create_project_button
        @browser.click_and_wait ProjectCreateUpdateSettingsPageId::CANCEL_CREATE_PROJECT_LINK
    end

    def select_project_date_format(date_format)
        @browser.select(ProjectCreateUpdateSettingsPageId::PROJECT_DATE_FORMAT_DROPDOWN, date_format)
    end

    def set_numeric_precision_to(project, precision)
        location = @browser.get_location
        navigate_to_project_admin_for(project) unless location =~ /#{project.identifier}\/admin\/edit/
        click_show_advanced_options_link
        @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_PRECISION_ID, precision.to_s)
        click_save_link
    end


    def type_project_email_sender_name(name)
        @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_EMAIL_SENDER_NAME_ID, name)
    end

    def type_project_email_address(email)
        @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_EMAIL_ADDRESS_ID, email)
    end

    def type_project_repos_path(repos_path)
        @browser.type(ProjectCreateUpdateSettingsPageId::REPORSITORY_CONFIG_PATH_NAME, repos_path)
    end


    def check_project_anonymous_accessible_in_checkbox
        @browser.click(ProjectCreateUpdateSettingsPageId::PROJECT_ANONYMOUS_ACCESSIBLE_ID) if @browser.is_not_checked(ProjectCreateUpdateSettingsPageId::PROJECT_ANONYMOUS_ACCESSIBLE_ID)
    end

    def uncheck_project_anonymous_accessible_in_checkbox
        @browser.click(ProjectCreateUpdateSettingsPageId::PROJECT_ANONYMOUS_ACCESSIBLE_ID) if @browser.is_checked(ProjectCreateUpdateSettingsPageId::PROJECT_ANONYMOUS_ACCESSIBLE_ID)
    end

    def enable_project_anonymous_accessible_on_project_admin_page
        check_project_anonymous_accessible_in_checkbox
        click_save_link
    end

    def disable_project_anonymous_accessible_on_project_admin_page
        uncheck_project_anonymous_accessible_in_checkbox
        click_save_link
    end

    def create_new_project_from_template(new_project_name, project_template_identifier, template_origin=nil)
        create_new_project(new_project_name, :template_identifier => project_template_identifier, :template_origin => template_origin)
        project_created_from_template = Project.find_by_identifier(new_project_name)
        project_created_from_template.activate
        project_created_from_template
    end

    def click_auto_enroll_as_read_only_button
        @browser.click(ProjectCreateUpdateSettingsPageId::PROJECT_ENROLL_USER_TYPE_READONLY_ID)
    end

    def check_auto_enroll_all_users_in_checkbox
        @browser.click(ProjectCreateUpdateSettingsPageId::ENABLE_AUTO_ENROLL_ID) if @browser.is_not_checked(ProjectCreateUpdateSettingsPageId::ENABLE_AUTO_ENROLL_ID)
    end

    def uncheck_auto_enroll_all_users_in_checkbox
        @browser.click(ProjectCreateUpdateSettingsPageId::ENABLE_AUTO_ENROLL_ID) if @browser.is_checked(ProjectCreateUpdateSettingsPageId::ENABLE_AUTO_ENROLL_ID)
    end

    def uncheck_I_will_be_a_member_checkbox
        @browser.click(ProjectCreateUpdateSettingsPageId::AS_MEMBER_ID) if @browser.is_checked(ProjectCreateUpdateSettingsPageId::AS_MEMBER_ID)
    end

    def should_be_able_to_cancel_the_export_process
      @browser.click_and_wait(ProjectCreateUpdateSettingsPageId::CANCEL_LINK)
      assert_current_url("/projects/#{@project.identifier}/admin/edit")
    end

    def full_member_should_be_able_to_cancel_the_export_process
      @browser.click_and_wait(ProjectCreateUpdateSettingsPageId::CANCEL_LINK)
      assert_current_url("/projects/#{@project.identifier}/team/list")
    end

    def create_a_project_with_membership_requstable_unchecked(project_name)
        @browser.type(ProjectCreateUpdateSettingsPageId::PROJECT_NAME_ID, project_name)
        @browser.click_and_wait(ProjectCreateUpdateSettingsPageId::CREATE_PROJECT_LINK)
    end

    def register_and_enable_anonymous_accessible(project)
      as_admin do
        set_new_license_for_project(SetupHelper.license_key_for_test(:allow_anonymous => true), SetupHelper.licensed_to_for_test)
        navigate_to_project_admin_for(project)
        enable_project_anonymous_accessible_on_project_admin_page
      end
    end

    private
    def set_options(options={})
        options.each do |key, value|
            case value
            when TrueClass
                @browser.check(project_key_settings(key))
            when FalseClass
                @browser.uncheck(project_key_settings(key))
            when String
                @browser.type(project_key_settings(key), value)
            end
        end
    end
end
