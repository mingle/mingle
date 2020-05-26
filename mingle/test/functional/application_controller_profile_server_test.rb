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
require File.expand_path(File.dirname(__FILE__) + '/../messaging/messaging_test_helper')

class ApplicationControllerProfileServerTest < ActionController::TestCase

  def setup
    clear_license
    FEATURES.deactivate("db_licensing")
    Clock.fake_now(:year => 2008, :month => 7, :day => 12)

    MingleConfiguration.app_namespace = "parsley"
    @http_stub = HttpStub.new
    ProfileServer.configure({:url => "https://profile_server"}, @http_stub)
  end

  def teardown
    ProfileServer.reset
    MingleConfiguration.app_namespace = nil
    Clock.reset_fake
    FEATURES.activate("db_licensing")
    CurrentLicense.clear_cache
  end

  def test_should_not_show_downgrade_popup_for_system_user
    @controller = create_controller UsersController, :own_rescue_action => false
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    admin = login_as_admin
    admin.update_attribute(:system, true)

    setup_license_on_profile_server("subscription_expires_on" => '2008-07-01')

    MingleConfiguration.with_multitenancy_mode_overridden_to('true') do
      MingleConfiguration.with_new_buy_process_overridden_to('true') do
        get :index

        assert !assigns['downgrade_view']
        assert @response.body !~ /downgrade_lightbox/
      end
    end
  end

  def test_should_show_downgrade_popup_when_site_need_to_be_downgraded
    @controller = create_controller UsersController, :own_rescue_action => false
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin

    setup_license_on_profile_server("subscription_expires_on" => '2008-07-01')

    get :index
    assert !assigns['downgrade_view']
    assert @response.body !~ /downgrade_lightbox/
    MingleConfiguration.with_multitenancy_mode_overridden_to('true') do
      get :index
      assert !assigns['downgrade_view']
      assert @response.body !~ /downgrade_lightbox/

      MingleConfiguration.with_new_buy_process_overridden_to('true') do
        get :index

        assert assigns['downgrade_view']
        assert_match /downgrade_lightbox/, @response.body
      end
    end
  end

  def test_should_sync_user_when_record_user_activity
    @controller = create_controller UsersController, :own_rescue_action => false
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin

    setup_license_on_profile_server("subscription_expires_on" => '3008-07-01')
    get :index
    req = @http_stub.requests.find{|r| r.url =~ /users\/sync/}

    assert_equal "https://profile_server/organizations/parsley/users/sync.json", req.url
    post_attrs = JSON.parse(req.body)["user"]
    assert_equal User.current.email,  post_attrs['email']
    assert_equal User.current.login_access.last_login_at.iso8601,  post_attrs['last_login_at']
  end

  def setup_license_on_profile_server(data={})
    response = {
      "name" => "parsley",
      "subscription_expires_on" => "2021-06-10",
      "allow_anonymous" => true,
      "product_edition" => "Mingle Enterprise",
      "max_active_full_users" => 200,
      "max_active_light_users" => 10,
      "users_url" => "https://profile_server/organizations/parsley/users.json",
      "paid?" => false,
      "trial?" => true
    }.merge(data)
    @http_stub.register_get_response('https://profile_server/organizations/parsley.json', [200, response.to_json])
  end

end
