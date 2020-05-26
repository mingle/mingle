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

# frozen_string_literal: true
require File.expand_path('../../test_helper', __FILE__)

class SaasTosControllerTest < ActionDispatch::IntegrationTest

  EXPECTED_MINGLE_ROOT_PATH = '/'

  def setup
    SaasTos.clear_cache!
    @admin_user = login(create(:user, login: :admin, admin: true))
  end

  def teardown
    SaasTos.clear_cache!
  end

  def test_show_should_have_link_to_terms_of_service

    get saas_tos_show_url
    Rails.logger.info("\n\n\n-----#{@response.inspect}---------\n\n\n") unless @response.status == 200
    assert_response :success
    assert_select "a[target='_blank']", :text => "Terms of Service"
    assert_select 'textarea', :count => 0
  end

  def test_should_skip_tos_if_already_accepted
    SaasTos.accept(@admin_user)
    get saas_tos_show_url
    assert_redirected_to EXPECTED_MINGLE_ROOT_PATH
  end

  def test_should_mark_tos_as_accepted
    post saas_tos_accept_url
    assert SaasTos.accepted?
    saas_tos = SaasTos.first
    assert saas_tos
    assert saas_tos.accepted
    assert_equal @admin_user.email, saas_tos.user_email
  end

  def test_should_redirect_to_landing_page_on_tos_accept
    post saas_tos_accept_url
    assert_redirected_to EXPECTED_MINGLE_ROOT_PATH
  end
end
