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

require File.expand_path(File.dirname(__FILE__) + '/../../functional_test_helper')

class PlannerApplicationControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller ProgramsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
  end

  def test_should_check_user_access_for_request_when_planner_is_inaccessible
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    rescue_action_in_public!
    assert_raise ErrorHandler::UserAccessAuthorizationError do
      get :index
    end
  end

  def test_should_check_user_access_for_request_when_planner_is_accessible
    register_license(:product_edition => Registration::ENTERPRISE)
    rescue_action_in_public!
    get :index
    assert_response :success
  end

  def test_should_not_show_invite_to_team
    get :index
    assert_select '.invite-to-team button', :count => 0

    get :index
    assert_select '.invite-to-team button', :count => 0
  end

  def test_current_tab_defaults_to_timeline
    @controller = create_controller PlansController
    get :show, :program_id => program('simple_program').to_param
    assert_response :success
    assert_select "li.selected a", :text => "Plan"
    assert_select "li.selected a", :text => "Features", :count => 0
    assert_select "li.selected a", :text => "Projects", :count => 0
  end
end
