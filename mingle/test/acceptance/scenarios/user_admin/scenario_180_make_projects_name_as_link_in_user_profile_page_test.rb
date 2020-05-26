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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: mingle_admin
class Scenario180MakeProjectsNameAsLinkInUserProfilePageTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)

    @project = create_project(:prefix => 'sc180_1', :admins => [@mingle_admin, @project_admin], :users => [@team_member], :read_only_users => [@read_only_user], :anonymous_accessible => true )
    @another_project = create_project(:prefix => 'sc180_2', :admins => [@project_admin], :users => [@team_member], :read_only_users => [@read_only_user], :anonymous_accessible => true )
  end

  def test_clicking_the_project_link_in_your_own_profile_will_take_you_to_this_projects_overview_page
     login_as_admin_user
     go_to_profile_page
     @browser.click_and_wait("link=#{@project.name}")
     assert_current_on_overview_page_for(@project)
  end


  def test_clicking_project_link_in_another_users_profile_will_take_you_to_this_projects_team_member_list
    login_as_admin_user
    open_show_profile_for(@project_admin)
    @browser.click_and_wait("link=#{@another_project.name}")
    assert_current_on_team_member_page_for(@another_project)
  end

  def test_non_mingle_admin_user_should_be_able_to_navigate_to_the_projects_they_belong_to_from_their_profile_pages
    login_as_project_member
    open_show_profile_for(@team_member)
    @browser.click_and_wait("link=#{@another_project.name}")
    assert_current_on_overview_page_for(@another_project)
  end

end
