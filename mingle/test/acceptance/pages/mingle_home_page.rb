# -*- coding: utf-8 -*-

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

module MingleHomePage

  def assert_no_projects_info_message_present_for_admin
    @browser.assert_element_matches('no-projects', /There are no projects in your Mingle instance/)
  end

  def assert_project_link_present(project)
    @browser.assert_element_present(project_identifier_link(project))
  end

  def assert_project_links_present(*projects)
    projects.each do |project|
      assert_project_link_present(project)
    end
  end

  def assert_project_link_not_present(project)
    @browser.assert_element_not_present(project_identifier_link(project))
  end

  def assert_new_project_link_not_present
     @browser.assert_element_not_present(MingleHomePageId::NEW_PROJECT_LINK)
   end

   def assert_new_project_link_present
     @browser.assert_element_present(MingleHomePageId::NEW_PROJECT_LINK)
   end

  def assert_project_is_present_and_requestable_but_not_accessible(project_name)
    @browser.assert_element_not_present(project_name_link(project_name))
    project_id = project_name.gsub(" ","_")
    @browser.assert_text(css_locator("div.project h2 span.not-accessible-project"), project_name)
    assert_project_request_link_present_on_project_list(project_id)
  end


  def user_can_only_see_this_project_but_can_not_access_or_request_it
     @browser.open "/projects/"
     @browser.assert_text(css_locator("div.project h2 span.not-accessible-project"), @project.name)
     assert_project_request_link_not_present_on_project_list(@project.identifier)
   end


   def non_member_user_can_access_this_project_and_request_it(project_name)
     login_as 'bob'
     @browser.open "/projects/"
     assert_project_is_accessible_and_requestable(project_name)
   end

   def user_can_only_see_this_project_and_can_request_it(project_name)
     @browser.open "/projects/"
     assert_project_is_present_and_requestable_but_not_accessible(project_name)
   end

  def assert_project_not_found(project_name)
    @browser.assert_element_not_present(project_name_link(project_name))
    @browser.assert_text_not_present(project_name)
  end

  def user_should_be_able_to_access_but_not_able_to_request
    @browser.open "/projects/"
    assert_project_is_accessible_not_requestable(@project.name)
  end


  def user_can_access_this_project_and_request_it
    @browser.open "/projects/"
    assert_project_is_accessible_and_requestable(@project.name)
  end

  def assert_project_is_accessible_and_requestable(project_name)
     @browser.assert_element_present(project_name_link(project_name))
     project_id = project_name.gsub(" ","_")
     @browser.assert_element_present(css_locator("a[href='/projects/#{project_id}/admin/request_membership']"))
   end

   def assert_project_is_accessible_not_requestable(project_name)
     @browser.assert_element_present(project_name_link(project_name))
     project_id = project_name.gsub(" ","_")
     assert_project_request_link_not_present_on_project_list(project_id)
   end

   def assert_project_request_link_not_present_on_project_list(project_id)
      @browser.assert_element_not_present(css_locator("a[href='/projects/#{project_id}/admin/request_membership']"))
    end

    def assert_project_request_link_present_on_project_list(project_id)
      @browser.assert_element_present(css_locator("a[href='/projects/#{project_id}/admin/request_membership']"))
    end

    def assert_mingle_explore_tab_not_present_for(project)
       @browser.open("/projects/#{project.identifier}")
       assert_tab_not_present("Explore Mingle")
     end

     def assert_mingle_explore_tab_present_for(project)
        @browser.open("/projects/#{project.identifier}")
        assert_tab_present("Explore Mingle")
     end

     def assert_current_on_overview_page_for(project)
       @browser.assert_location("/projects/#{project.identifier}/overview")
       assert_tab_highlighted("Overview")
     end

     def assert_delete_this_and_create_template_from_this_project_links_not_present
       assert_link_not_present(MingleHomePageId::DELETE_THIS_LINK)
       assert_link_not_present(MingleHomePageId::CREATE_TEMPLATE_FROM_PROJECT_LINK)
     end

     def assert_located_at_project_list_page
       @browser.assert_location('/projects')
     end

     def assert_about_link_not_present
       @browser.assert_element_not_present(MingleHomePageId::ABOUT_LINK)
     end

     def assert_about_link_present
       @browser.assert_element_present(MingleHomePageId::ABOUT_LINK)
     end

     def assert_only_full_seats_are_used_up_message(max_full_user)
       only_full_seats_are_used_up_message = "You've reached the maximum number of users for your site. Please get in touch with us for more at studios@thoughtworks.com."

     end

     def assert_both_full_and_light_seats_are_used_up_message
       both_full_and_light_seats_are_used_up_message = "You've reached the maximum number of users for your site. Please get in touch with us for more at studios@thoughtworks.com."
       assert_info_message(both_full_and_light_seats_are_used_up_message)
     end

     def assert_total_seats_are_used_up_message
       total_seats_are_used_up_message = "You've reached the maximum number of users for your site. Please get in touch with us for more at studios@thoughtworks.com."
       @browser.assert_text_present(total_seats_are_used_up_message)
     end

     def assert_create_your_first_project_messsage_present
       # @browser.assert_text_present("There are no projects in your Mingle instance – Create the first project now or click here for more information.")
       @browser.assert_element_present(MingleHomePageId::NO_PROJECTS_WARNING_ID)
       @browser.assert_text_present_in(MingleHomePageId::NO_PROJECTS_WARNING_ID, "There are no projects in your Mingle instance – Create the first project now or click here for more information.")
     end

     def assert_create_your_first_project_messsage_not_present
       @browser.assert_element_not_present(MingleHomePageId::NO_PROJECTS_WARNING_ID)
     end

     def assert_no_projects_available_warning_present
       @browser.assert_element_present(MingleHomePageId::NO_PROJECTS_AVAILABLE_WARNING_ID)
       @browser.assert_text_present_in(MingleHomePageId::NO_PROJECTS_AVAILABLE_WARNING_ID, "You are currently not a member of any project.")
     end

     def assert_no_projects_available_warning_not_present
       @browser.assert_element_not_present(MingleHomePageId::NO_PROJECTS_AVAILABLE_WARNING_ID)
     end


end
