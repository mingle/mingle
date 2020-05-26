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

class ProjectExportsControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller ProjectExportsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @project = first_project
  end
  
  # Bug 8029
  def test_cancel_button_shows_for_project_admins
    login_as_proj_admin
    get :confirm_as_project, :project_id => @project.identifier
    assert_response :success
    assert_select 'a.cancel'
  end
  
  # Bug 8029
  def test_cancel_button_shows_for_members
    login_as_member
    get :confirm_as_project, :project_id => @project.identifier
    assert_response :success
    assert_select 'a.cancel'
  end
end
