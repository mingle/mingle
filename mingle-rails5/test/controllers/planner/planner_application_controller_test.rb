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

require File.expand_path('../../../test_helper', __FILE__)

class PlannerApplicationControllerTest < ActionDispatch::IntegrationTest
  def setup
    create(:admin, login: :admin)
    login_as_admin
  end

  FORBIDDEN_MESSAGE = 'Either the resource you requested does not exist or you do not have access rights to that resource.'

  def test_should_check_user_access_for_request_when_planner_is_inaccessible
    @program = create(:program)
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    get check_in_test_url
    assert_response(302)
    assert_equal FORBIDDEN_MESSAGE, flash[:error]

  end

  def test_should_check_user_access_for_request_when_planner_is_accessible
    register_license(:product_edition => Registration::ENTERPRISE)
    get check_in_test_url :format => 'html'
    assert_response :success
    assert_equal 'Implementing this to test user access', response.body
  end

end
