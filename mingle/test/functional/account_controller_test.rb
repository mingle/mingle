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

class AccountControllerTest < ActionController::TestCase

  def setup
    ActionMailer::Base.deliveries = []
    MingleConfiguration.app_namespace = "parsley"
    @http_stub = HttpStub.new
    ProfileServer.configure({:url => "https://profile_server"}, @http_stub)
    login_as_member
  end

  def teardown
    ProfileServer.reset
    MingleConfiguration.app_namespace = nil
  end

  def test_edit
    licensed_to = 'foo'
    license_key = {:licensee =>licensed_to, :max_active_users => '10' ,:expiration_date => '2038-07-13', :product_edition => Registration::ENTERPRISE}
    CurrentLicense.register!(license_key.to_query, licensed_to)

    get :edit

    assert_response :success

    assert_equal 10, assigns['buy_tier']
    assert_equal true, assigns['include_planner']
  end

  def test_post_downgrade
    post :downgrade
    assert_response :success
    assert_match /window.location.reload/, @response.body
  end

  def test_update
    time = Time.parse('2015-01-13 12:22:26').utc
    Clock.now_is(time) do
      post :update, 'mingle-edition' => 'plus', :max_active_full_users => 22
    end
    assert_response :success

    org_requests = @http_stub.requests.select{|r| r.url =~ /organizations\/parsley\.json/ }
    assert_equal 1, org_requests.size
    req = org_requests.first

    assert_equal :put, req.http_method

    put_attrs = JSON.parse(req.body)["organization"]
    assert_equal 'Mingle Enterprise', put_attrs['product_edition']
    assert_equal 22, put_attrs['max_active_full_users']
    assert !put_attrs.has_key?('subscription_expires_on')
    assert_equal time.iso8601, put_attrs['buy_at']
  end

  def test_update_should_reset_current_license_status
    FEATURES.deactivate("db_licensing")
    assert_equal false, CurrentLicense.status.enterprise?
    setup_license_on_profile_server("product_edition" => "Mingle Enterprise",
                                    'max_active_full_users' => '22')

    post :update, 'mingle-edition' => 'plus', :max_active_full_users => 22
    assert_response :success

    assert_equal true, CurrentLicense.status.enterprise?
  ensure
    FEATURES.activate("db_licensing")
  end

  def test_should_auto_extend_expiration_date_1_week_if_it_was_less_than_1_week
    FEATURES.deactivate("db_licensing")
    time = Time.parse('2015-01-13 12:22:26').utc
    Clock.now_is(time) do
      setup_license_on_profile_server('subscription_expires_on' => '2015-01-11')

      post :update, 'mingle-edition' => 'basic', :max_active_full_users => 22
      assert_response :success

      req = @http_stub.requests.find{|r| r.http_method == :put}
      put_attrs = JSON.parse(req.body)["organization"]
      assert_equal '2015-01-20', put_attrs['subscription_expires_on']
    end
  ensure
    FEATURES.activate("db_licensing")
  end

  def test_should_reset_expiration_date_to_1_week_if_it_was_free_tier_license
    FEATURES.deactivate("db_licensing")
    time = Time.parse('2015-01-13 12:22:26').utc
    Clock.now_is(time) do
      setup_license_on_profile_server('subscription_expires_on' => '2099-01-11',
                                      "max_active_full_users" => 5)

      post :update, 'mingle-edition' => 'basic', :max_active_full_users => 25
      assert_response :success

      req = @http_stub.requests.find{|r| r.http_method == :put}
      put_attrs = JSON.parse(req.body)["organization"]
      assert_equal '2015-01-20', put_attrs['subscription_expires_on']
    end
  ensure
    FEATURES.activate("db_licensing")
  end

  def test_should_reset_expiration_date_to_10_years_if_user_chose_free_tier_license
    FEATURES.deactivate("db_licensing")
    time = Time.parse('2015-01-13 12:22:26').utc
    Clock.now_is(time) do
      setup_license_on_profile_server('subscription_expires_on' => "2015-02-13 00:00:00",
                                      "max_active_full_users" => 15)

      post :update, 'mingle-edition' => 'basic', :max_active_full_users => 5
      assert_response :success

      req = @http_stub.requests.find{|r| r.http_method == :put}
      put_attrs = JSON.parse(req.body)["organization"]
      assert_equal '2025-01-13', put_attrs['subscription_expires_on']
    end
  ensure
    FEATURES.activate("db_licensing")
  end

  def test_should_send_alert_email_after_updated
    MingleConfiguration.with_ask_for_upgrade_email_recipient_overridden_to('mingle-dev@thoughtworks.com') do
      post :update, 'mingle-edition' => 'basic', :max_active_full_users => 22, :contact_email => 'x@x.com', :contact_phone => '4423345555'
      assert_response :success
      assert_equal 1, ActionMailer::Base.deliveries.size
      email = ActionMailer::Base.deliveries.first
      assert_equal "Alert: Mingle SaaS BUY NOW: #{MingleConfiguration.site_url}", email.subject
      assert_equal [MingleConfiguration.ask_for_upgrade_email_recipient], email.to
      assert_include "x@x.com", email.body
      assert_include "4423345555", email.body
    end
  end

  def setup_license_on_profile_server(data={})
    response = {
      "name" => "parsley",
      "subscription_expires_on" => "2021-06-10",
      "allow_anonymous" => true,
      "product_edition" => "Mingle Enterprise",
      "max_active_full_users" => 200,
      "max_active_light_users" => 10,
      "users_url" => "https://profile_server/organizations/parsley/users.json"
    }.merge(data)
    @http_stub.register_get_response('https://profile_server/organizations/parsley.json', [200, response.to_json])
  end

end
