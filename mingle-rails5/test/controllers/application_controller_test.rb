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
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  def setup
    login create(:user)
  end

  def teardown
    Thread.current[:rollback_only] = nil
    logout_as_nil
  end

  NOT_FOUND_ERROR_MESSAGE = 'Either the resource you requested does not exist or you do not have access rights to that resource'

  def test_all_response_should_have_csp_headers_set

    expected_csp_policy  = "default-src 'self'; script-src 'unsafe-inline' 'unsafe-eval' 'self' https://*.pingdom.net"+
        ' cdn.mxpnl.com https://cdn.firebase.com https://*.firebaseio.com https://*.cloudfront.net'+
        " https://s3.amazonaws.com platform.twitter.com; connect-src 'self' https://s3-us-west-1.amazonaws.com"+
        ' https://*.s3-us-west-1.amazonaws.com wss://*.firebaseio.com https://*.cloudfront.net https://api.mixpanel.com https://*.pingdom.net;'+
        " img-src * 'self' data: blob:; style-src 'unsafe-inline' 'self' https://*.cloudfront.net; font-src 'self'"+
        " https://*.cloudfront.net data: themes.googleusercontent.com; frame-src 'self' https://www.google.com maps.google.com"+
        " calendar.google.com https://*.firebaseio.com https://*.thoughtworks.com platform.twitter.com; frame-ancestors 'self';"

    get call_me_in_test_url

    assert_equal expected_csp_policy, response.headers['Content-Security-Policy']
    assert_equal response.headers['Content-Security-Policy'], response.headers['X-Content-Security-Policy']
    Rails.application.routes_reloader.reload!
  end

  def test_all_response_should_have_security_headers_set


    get call_me_in_test_url

    assert_equal 'nosniff', @response.headers['X-CONTENT-TYPE-OPTIONS']
    assert_equal '1; mode=block', @response.headers['X-XSS-Protection']
    assert_equal 'SAMEORIGIN', @response.headers['X-Frame-Options']
    Rails.application.routes_reloader.reload!
  end

  def test_should_clear_thread_local_cache_on_every_request

    ThreadLocalCache.set('dddd', 'it shoould get cleared')
    get call_me_in_test_url
    assert_nil ThreadLocalCache.get('dddd')
    Rails.application.routes_reloader.reload!
  end

  def test_should_redirect_to_saas_tos_when_not_accepted
    Cache.delete('saas_tos')
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to('true') do

      get call_me_in_test_url

      assert_response :redirect
      assert_redirected_to controller: 'saas_tos', action: 'show'
    end
  end

  def test_should_not_redirect_to_license_warning_if_license_is_already_expired
    travel_to(Date.parse('2008-07-31')) do
      expired_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-30', :max_active_users => 100}.to_query
      CurrentLicense.register!(expired_key, 'Funky Worm')

      get call_me_in_test_url

      assert_response :success
    end
  end

  def test_should_redirect_to_license_warning_when_user_has_not_seen_the_warning_and_license_is_expiring_soon
    travel_to(Date.parse('2008-07-05')) do
      expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100}.to_query
      CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
      get call_me_in_test_url
      assert_redirected_to :controller => :license, :action => :warn
    end
  end

  def test_should_not_redirect_to_license_warning_on_saas_for_unpaid_license_when_license_is_expiring_soon
    travel_to(Date.parse('2008-07-05')) do
      MingleConfiguration.with_multitenancy_mode_overridden_to(true) do
        expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100, :paid => false}.to_query
        CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
        get call_me_in_test_url
        assert_response :success
      end
    end
  end

  def test_should_not_redirect_to_license_warning_when_license_is_expiring_soon_but_user_has_already_dismissed_warning
    travel_to(Date.parse('2008-07-05')) do
      setup_session license_expiration_warning_dismissed: true
      expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100}.to_query
      CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')

      get call_me_in_test_url
      assert_response :success
    end
  end

  def test_call_to_api_should_not_redirect_to_license_warning_when_license_is_expiring_soon
    travel_to(Date.parse('2008-07-05')) do
      expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100}.to_query
      CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')

      request_path = "/api/v2#{call_me_in_test_path}.xml"
      get request_path
      assert_response :success
    end
  end

  def test_should_not_redirect_to_license_warning_when_license_is_not_expiring_soon
    travel_to(Date.parse('2008-07-05')) do
      future_license_key = {:licensee => 'Funky Worm', :expiration_date => '2088-07-31', :max_active_users => 100}.to_query
      CurrentLicense.register!(future_license_key, 'Funky Worm')
      get call_me_in_test_url
      assert_response :success
    end
  end

  def test_should_clear_current_user
    user = create(:user)
    User.current  = user
    application_controller = ApplicationController.new
    application_controller.send(:clear_current_user)
    assert User.current.anonymous?
  end

  def test_should_record_and_clear_current_controller_name
    application_controller = ApplicationController.new
    application_controller.send(:record_current_controller_name) do
      assert_equal Thread.current[:controller_name], application_controller.class.controller_path
    end
    assert_nil Thread.current[:controller_name]
  end

  def test_should_rollback_a_transaction_for_post_request_when_there_are_errors
    SaasTosController.any_instance.stubs(:error_message).returns('error')
    post saas_tos_accept_url
    assert Thread.current[:rollback_only]
  end

  def test_should_not_wrap_get_requests_within_a_transaction
    get saas_tos_show_url
    assert_nil Thread.current[:rollback_only]
  end

  def test_should_not_rollback_a_transaction_for_post_request_when_there_are_no_errors
    post saas_tos_accept_url
    assert_nil Thread.current[:rollback_only]
  end

  def test_should_forbid_a_request_when_feature_is_deactivated
    FeatureToggle::Features.any_instance.stubs(:active_action?).with('saas_tos','accept').returns(false)
    post saas_tos_accept_url
    assert_response :not_found
  end

  def test_should_return_license_error_if_its_invalid
    travel_to(Date.parse('2008-07-31')) do
      MingleConfiguration.with_new_buy_process_overridden_to(true) do
        expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-30', :max_active_users => 100, :paid => true}.to_query
        CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
        get call_me_in_test_url
        assert_not_nil flash[:license_error]
      end
    end
  end

  def test_should_return_license_error_nil_if_its_valid
    travel_to(Date.parse('2008-07-30')) do
      MingleConfiguration.with_new_buy_process_overridden_to(true) do
        expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :paid => true}.to_query
        CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
        get call_me_in_test_url
        assert_nil flash[:license_error]
      end
    end
  end

  def test_should_render_to_downgrade_partial_if_license_is_downgrade_and_user_is_not_system_user
    travel_to(Date.parse('2008-07-31')) do
      login(create(:admin)) do
        MingleConfiguration.with_new_buy_process_overridden_to(true) do
          expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-30', :paid => false}.to_query
          CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
          License.get.update_attributes(:license_key => expiring_soon_license_key)
          CurrentLicense.clear_cache
          get call_me_in_test_url
          assert_response :success
          assert_template partial: '_downgrade'
        end
      end
    end
  end

  def test_should_flash_error_and_redirect_to_login_if_user_is_not_activated
    expected_flash_message = 'is no longer active. Please contact your Mingle administrator to resolve this issue.'
    login(create(:user, :deactivated )) do
      get call_me_in_test_url

      assert_match expected_flash_message, flash[:error]
      assert_redirected_to login_profile_path
    end

  end

  def test_should_response_status_to_be_missing_if_user_is_not_activated_and_request_format_is_xml
    login(create(:user, :deactivated )) do
      get call_me_in_test_url :format => 'xml'

      assert_equal 'Deactivated user.', response.body
      assert_response :missing
    end
  end

  def test_should_render_to_external_authentication_view_if_using_external_authenticator
    user_email = "#{unique_name}@email.com"
    login(create(:user, :deactivated, email: user_email )) do
      Authenticator.expects(:using_external_authenticator?).returns(true)

      get call_me_in_test_url

      assert_template 'errors/external_authentication_error'
      assert_response(403)
    end
  end

  def test_all_response_should_have_x_frame_options_set_to_sameorigin
    get call_me_in_test_url

    assert_response :ok
    assert_equal 'SAMEORIGIN', @response.headers['X-Frame-Options']
  end

  def test_site_activity_should_track_admin_user_and_sync_profile_server_if_profile_server_configured
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      assert_nil Cache.get("site_activity_#{User.current.id}")
      fake_event_tracker = mock()
      EventsTracker.expects(:new).returns(fake_event_tracker)
      fake_event_tracker.expects(:track).with(':'+User.current.login, 'site_activity', {:site_name => nil, :trialing => false})
      ProfileServer.expects(:configured?).returns(true)
      ProfileServer.expects(:sync_user).with(User.current).at_least_once

      get call_me_in_test_url

      assert_equal Cache.get("site_activity_#{User.current.id}"), 'set'
    end
  end

  def test_site_activity_should_track_admin_user_and_not_sync_to_profile_server_if_not_configured
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      assert_nil Cache.get("site_activity_#{User.current.id}")
      fake_event_tracker = mock()
      EventsTracker.expects(:new).returns(fake_event_tracker)
      fake_event_tracker.expects(:track).with(':'+User.current.login, 'site_activity', {:site_name => nil, :trialing => false})
      ProfileServer.expects(:sync_user).with(User.current).never

      get call_me_in_test_url

      assert_equal Cache.get("site_activity_#{User.current.id}"), 'set'
    end
  end

  def test_site_activity_should_not_track_system_user
    MingleConfiguration.with_metrics_api_key_overridden_to('wpc4eva') do
      user_email = "#{unique_name}@email.com"
      system_user = create(:user, :deactivated, email: user_email, system:true)
      login(system_user) do
        fake_event_tracker = mock()
        EventsTracker.expects(:new).never
        fake_event_tracker.expects(:track).with(':'+system_user.login, 'site_activity', {:site_name => nil, :trialing => false}).never
        ProfileServer.expects(:sync_user).with(system_user).never

        get call_me_in_test_url

        assert_nil Cache.get("site_activity_#{system_user.id}")
      end
    end
  end

  def test_should_rescue_record_not_found_exception_and_display_404
    get raise_exception_for_test_url , params: {exception: 'ActiveRecord::RecordNotFound'}

    assert_response :not_found
    assert_template 'errors/not_found'
  end

  def test_should_rescue_record_not_found_exception_and_display_404_in_xml
    request_path = "#{raise_exception_for_test_path}.xml"
    get request_path, params: {exception: 'ActiveRecord::RecordNotFound'}

    assert_response :not_found
    assert_include '<?xml version="1.0" encoding="UTF-8"?>', @response.body
  end

  def test_should_rescue_invalid_resource_error_exception_and_display_404
    get raise_exception_for_test_path, params: {exception: 'ErrorHandler::InvalidResourceError'}

    assert_response :not_found
    assert_include NOT_FOUND_ERROR_MESSAGE, @response.body
  end

  def test_should_rescue_invalid_argument_error_exception_and_display_400
    get raise_exception_for_test_path, params: {exception: 'ErrorHandler::InvalidArgumentError'}

    assert_response 400
    assert_template 'errors/unknown'
  end

  def test_should_rescue_invalid_argument_error_exception_and_display_400_in_xml_format
    request_path = "#{raise_exception_for_test_path}.xml"
    get request_path, params: {exception: 'ErrorHandler::InvalidArgumentError'}

    assert_response 400
  end

  def test_should_rescue_invalid_ticket_error_exception_by_redirecting_to_forgot_password_action
    get raise_exception_for_test_path, params: {exception: 'ErrorHandler::InvalidTicketError'}

    assert_redirected_to forgot_password_profile_path
  end

  def test_should_rescue_connection_not_established_exception_with_status_404
    get raise_exception_for_test_path, params: {exception: 'ActiveRecord::ConnectionNotEstablished'}

    assert_response :not_found
  end

  def test_should_rescue_connection_timeout_exception_with_status_500
    get raise_exception_for_test_path, params: {exception: 'ActiveRecord::ConnectionTimeoutError'}

    assert_response :internal_server_error
    assert_template :'errors/unknown'
  end

  def test_should_rescue_undefined_exception_with_status_500
    get raise_exception_for_test_path, params: {exception: 'NullPointerException'}

    assert_response :internal_server_error
    assert_template :'errors/unknown'
  end

  def test_should_rescue_method_not_allowed_exception_with_status_405
    get raise_exception_for_test_path, params: {exception: 'ActionController::MethodNotAllowed'}

    assert_response :method_not_allowed
    assert_template :'errors/not_found'
  end

  def test_should_rescue_method_not_allowed_exception_for_api_request_with_status_405
    request_path = "#{raise_exception_for_test_path}.xml"
    get request_path, params: {exception: 'ActionController::MethodNotAllowed'}

    assert_response :method_not_allowed
    assert_template nil
  end

  def test_should_rescue_invalid_resource_error_with_status_404
    get raise_exception_for_test_path, params: {exception: 'ErrorHandler::InvalidResourceError'}

    assert_response :not_found
    assert_template 'errors/not_found'
  end

  def test_should_rescue_user_access_authorization_error_with_status_403
    request_path = "#{raise_exception_for_test_path}.xml"
    get request_path, params: {exception: 'ErrorHandler::UserAccessAuthorizationError'}

    assert_response 403
    assert_template nil
  end

  def test_should_rescue_unauthorization_error_with_status_403
    forbidden_message = 'Either the resource you requested does not exist or you do not have access rights to that resource.'
    login(create(:light_user))
    get '/license/show.xml'

    assert_response 403
    assert_template nil
    assert_include forbidden_message, @response.body
  end
end
