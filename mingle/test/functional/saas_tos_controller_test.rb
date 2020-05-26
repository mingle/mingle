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
require 'saas_tos_controller'

class SaasTosControllerTest < ActionController::TestCase
  def setup
    clear_license
    @controller = create_controller SaasTosController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @admin_user = login_as_admin
  end

  def teardown
    SaasTos.clear_cache!
  end

  def test_show_should_have_link_to_terms_of_service
    get 'show'
    assert_response :success
    assert_select "a[target='_blank']", :text => "Terms of Service"
    assert_select 'textarea', :count => 0
  end

  def test_should_skip_tos_if_already_accepted
    SaasTos.accept(User.first)
    get 'show'
    assert_redirected_to(root_url)
  end

  def test_should_mark_tos_as_accepted
    post 'accept'
    assert SaasTos.accepted?
    saas_tos = SaasTos.first
    assert saas_tos
    assert saas_tos.accepted
    assert_equal @admin_user.email, saas_tos.user_email
  end

  def test_should_redirect_to_landing_page_on_tos_accept
    post 'accept'
    assert_redirected_to(root_url)
  end
end
