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

class ProjectHealthCheckControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller ProjectsController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
  end

  def test_health_check_should_redirect_back_to_url_if_it_given
    with_first_project do |project|
      get :health_check, :forward_url => "http://test.host/some_path", :project_id => project.identifier
      assert_redirected_to "http://test.host/some_path"
    end
  end

  def test_health_check_should_redirect_back_to_refer_url_if_from_url_not_given
    with_first_project do |project|
      @request.env["HTTP_REFERER"] = "http://test.host/some_path"
      get :health_check, :project_id => project.identifier
      assert_redirected_to "http://test.host/some_path"
    end
  end

  def test_manually_corruption_check_through_admin_advanced
    with_new_project do |project|
      get :show, :project_id => project.identifier  # prep controller for use of url_for
      setup_missing_column_property(project, 'iteration')

      @request.env["HTTP_REFERER"] = url_for(:controller => 'projects', :action => :advanced, :project_id => project.identifier)
      get :health_check, :project_id => project.identifier
      follow_redirect

      assert_show_corruption_info(/iteration<\/b><\/a> is corrupt/)
    end
  end

  protected

  def assert_show_corruption_info(message)
    assert_select("div#flash div#project_corruption_info", :html => message)
  end

  def setup_missing_column_property(project, prop_name)
    setup_property_definitions(prop_name => [1, 2])
    project.card_schema.remove_column('cp_' + prop_name)
  end

end
