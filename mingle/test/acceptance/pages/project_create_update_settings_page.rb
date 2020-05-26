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

module ProjectCreateUpdateSettingsPage
  def assert_project_membership_requestable_present
    @browser.assert_element_present(ProjectCreateUpdateSettingsPageId::PROJECT_MEMBERSHIP_REQUESTABLE_ID)   
  end

  def the_membership_request_check_box_should_be_unchecked_by_default
    @browser.assert_not_checked(ProjectCreateUpdateSettingsPageId::PROJECT_MEMBERSHIP_REQUESTABLE_ID)  
  end

  def assert_precision_set_to(precision)
    @browser.assert_value(ProjectCreateUpdateSettingsPageId::PROJECT_PRECISION_ID, precision.to_s)
  end

  def should_not_see_require_membership_option_in_project_template
    @browser.assert_element_not_present(ProjectCreateUpdateSettingsPageId::PROJECT_MEMBERSHIP_REQUESTABLE_ID)
    @browser.assert_text_not_present("Allow logged in users to request membership to this project")
  end
  
  def assert_selected_project_date_format(date_format)
     @browser.assert_value(ProjectCreateUpdateSettingsPageId::PROJECT_DATE_FORMAT_DROPDOWN, date_format)
   end
   
   
   def assert_auto_enroll_all_users_checkbox_is_unchecked
     @browser.assert_not_checked(ProjectCreateUpdateSettingsPageId::ENABLE_AUTO_ENROLL_ID) 
   end
   
   def assert_project_identifier(project_identifier)
     @browser.assert_value(ProjectCreateUpdateSettingsPageId::PROJECT_IDENTIFIER_NAME, project_identifier)
   end
   
   def assert_project_anonymous_accessible_present
     @browser.assert_element_present(ProjectCreateUpdateSettingsPageId::PROJECT_ANONYMOUS_ACCESSIBLE_ID)
   end

   def assert_project_anonymous_accessible_not_present
     @browser.assert_element_not_present(ProjectCreateUpdateSettingsPageId::PROJECT_ANONYMOUS_ACCESSIBLE_ID)   
   end

   def assert_project_in_list_not_linkable(project_name, index=0)
     @browser.assert_element_text(css_locator("span.not-accessible-project", index), project_name)
   end

   def assert_I_will_be_a_member_checkbox_checked
     @browser.assert_checked(ProjectCreateUpdateSettingsPageId::AS_MEMBER_ID) 
   end
   
   def assert_project_admin_menu_item_is_highlighted(menu_item)
     highlighted = @browser.get_eval("#{class_locator('current-selection', 0)}.innerHTML.unescapeHTML()")
     assert_equal(menu_item, highlighted.strip)
   end
   
   def assert_continue_to_export_and_cancel_links_present
     @browser.assert_element_present(ProjectCreateUpdateSettingsPageId::CONTINUE_TO_EXPORT_LINK)
     @browser.assert_element_present(ProjectCreateUpdateSettingsPageId::CANCEL_LINK)
   end
end
