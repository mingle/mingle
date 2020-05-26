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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class NavigationHeaderTest < ActionController::TestCase

  def setup
    @controller = create_controller ProjectsController
    @member_user = User.find_by_login('member')
    @admin = login_as_admin
  end

  def test_should_show_user_details_link_if_user_is_mingle_admin
    get :index
    assert_tag :a, :content => 'Manage users'
  end

  def test_should_show_user_details_link_if_user_is_project_admin
    project_admin = first_project.admins.first
    set_current_user(project_admin) do
      get :index
      assert_tag :a, :content => 'Manage users'
    end
  end

  def test_should_show_configure_oauth_clients_link_only_if_user_is_admin
    set_current_user(@admin) do
      get :index
      assert_tag :a, :content => 'OAuth clients'
    end
    project_admin = first_project.admins.first
    set_current_user(project_admin) do
      get :index
      assert_no_tag :a, :content => 'OAuth clients'
    end
  end

  def test_project_can_be_created_and_imported_only_by_mingle_admin
    set_current_user(@admin) do
      get :index
      assert_tag :a, :content => 'New project'
      assert_tag :a, :content => 'Import project'
    end
    project_admin = first_project.admins.first
    set_current_user(project_admin) do
      get :index
      assert_no_tag :a, :content => 'New project'
      assert_no_tag :a, :content => 'Import project'
    end
    set_current_user(@member_user) do
      get :index
      assert_no_tag :a, :content => 'New project'
      assert_no_tag :a, :content => 'Import project'
    end
  end

  def test_tabs_visibility
    set_current_user(@admin) do
      get :index
      assert_select '#header-pills li a', :text => 'Programs'
      assert_select '#header-pills li.selected a', :text => 'Projects'
      assert_select '#header-pills li a', :text => 'Admin'
    end
    project_admin = first_project.admins.first
    set_current_user(project_admin) do
      get :index
      assert_select '#header-pills li a', :text => 'Programs'
      assert_select '#header-pills li.selected a', :text => 'Projects'
      assert_select '#header-pills li a', :text => 'Admin'
    end
    set_current_user(@member_user) do
      get :index
      assert_select '#header-pills li a', :text => 'Programs'
      assert_select '#header-pills li.selected a', :text => 'Projects'
      assert_select '#header-pills li a', :text => 'Admin', :count => 0
    end
  end

  def test_tabs_visibility_when_license_is_not_enterprise
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    set_current_user(@admin) do
      get :index
      assert_select '#header-pills li a', :text => 'Programs', :count => 0
      assert_select '#header-pills li a', :text => 'Admin'
      assert_select '#header-pills li.selected a', :text => 'Projects'
    end
    project_admin = first_project.admins.first
    set_current_user(project_admin) do
      get :index
      assert_select '#header-pills li a', :text => 'Programs', :count => 0
      assert_select '#header-pills li.selected a', :text => 'Projects'
      assert_select '#header-pills li a', :text => 'Admin'
    end
    set_current_user(@member_user) do
      get :index
      assert_select '#header-pills li a', :text => 'Programs', :count => 0
      assert_select '#header-pills li.selected a', :text => 'Projects'
      assert_select '#header-pills li a', :text => 'Admin', :count => 0
    end
  end
end
