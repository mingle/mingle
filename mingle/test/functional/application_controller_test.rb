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

class FakeUrlWriter
  def rewrite(_ = {})
    ''
  end
end

class ApplicationControllerTest < ActionController::TestCase
  include MessagingTestHelper

  def setup
    @controller = ApplicationController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @controller.request = @request
    @controller.response = @response
    @controller.params = {}
    @user = login_as_admin
    prepare()
  end

  def teardown
    Clock.reset_fake
  end

  NOT_FOUND_ERROR_MESSAGE = 'Either the resource you requested does not exist or you do not have access rights to that resource'

  def test_should_rescue_resource_not_found_exception_locally_and_display_404
    exception = ActiveRecord::RecordNotFound.new
    exception.set_backtrace([''])
    @controller.rescue_action_locally(exception)
    assert_include NOT_FOUND_ERROR_MESSAGE, @response.body
  end

  def test_should_rescue_resource_not_found_exception_publiclly_and_display_404
    exception = ActiveRecord::RecordNotFound.new
    exception.set_backtrace([''])
    @controller.rescue_action_in_public(exception)
    assert_include NOT_FOUND_ERROR_MESSAGE, @response.body
  end

  def test_display_404_for_xml_requests
    exception = ActiveRecord::RecordNotFound.new
    exception.set_backtrace([''])

    @request.request_uri = 'http://test.host/api/v2/projects/pa/cards/1234.xml'
    @controller.rescue_action_in_public(exception)

    assert_include NOT_FOUND_ERROR_MESSAGE, @response.body
    assert_include '<?xml version="1.0" encoding="UTF-8"?>', @response.body
  end

  def test_should_handle_mehtod_not_allowed_exception_on_html_request
    exception = ActionController::MethodNotAllowed.new('post')
    exception.set_backtrace([''])
    @controller.rescue_action_in_public(exception)
    assert_include NOT_FOUND_ERROR_MESSAGE, @response.body
  end

  def test_should_handle_mehtod_not_allowed_exception_on_api_request
    exception = ActionController::MethodNotAllowed.new('post', 'delete')
    exception.set_backtrace([''])
    @request.request_uri = 'http://test.host/projects.xml'
    @controller.rescue_action_in_public(exception)
    assert_response :method_not_allowed
    assert_equal 'POST, DELETE', @response.headers['Allow']
    assert_equal 'Only post and delete requests are allowed.', @response.body
  end

  def test_should_record_return_to_redirect_to_require_user_login
    exception = ApplicationController::UserAccessAuthorizationError.new
    exception.set_backtrace([''])
    logout_as_nil

    def @controller.params; {:controller => 'hello', :action => 'world' } end
    @request.request_uri = '/hello/world'
    @controller.rescue_action_in_public(exception)

    assert_equal({:controller => 'hello', :action => 'world' }, @controller.session['return-to'])
  end

  def test_should_show_400_error_on_oauth_request_on_plain_text
    exception = Oauth2::Provider::HttpsRequired.new('foo')
    exception.set_backtrace([''])

    result = @controller.rescue_action_in_public(exception)

    assert_response :bad_request
  end

  def test_should_redirect_to_install_controller_configure_site_url_action_when_no_site_url_property
    requires_jruby do
      @controller = create_controller UsersController, :own_rescue_action => true
      @request = ActionController::TestRequest.new
      @response = ActionController::TestResponse.new
      login_as_admin

      with_reset_site_url do
        java.lang.System.setProperty('mingle.siteURL', '')
        get :index
        assert_redirected_to :controller => :install
      end
    end
  end

  def test_should_show_buy_link_only_for_unpaid_saas_site
    @controller = create_controller UsersController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin
    get :index
    assert_select '#buy', :count => 0
    unpaid = LicenseStatus.new(:valid => true, :trial => true, :paid => false)
    paid = LicenseStatus.new(:valid => true, :trial => true, :paid => true)
    MingleConfiguration.with_multitenancy_mode_overridden_to('true') do
      Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
      get :index
      assert_select '#buy', :count => 0
      Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, paid)
      get :index
      assert_select '#buy', :count => 0
      MingleConfiguration.with_new_buy_process_overridden_to('true') do
        get :index
        assert_select '#buy', :count => 0
        Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
        get :index
        assert_select '#buy', :count => 1
      end
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  def test_should_not_show_buy_link_on_the_footer_for_unpaid_saas_site_when_display_export_banner_is_set
    @controller = create_controller UsersController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin
    unpaid = LicenseStatus.new(valid: true, trial: true, paid: false)
    MingleConfiguration.overridden_to(new_buy_process: true, multitenancy_mode: true,display_export_banner:true) do
    Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
      get :index
      assert_select '#ft #buy', :count => 0
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  def test_should_not_show_trial_count_down_for_unpaid_saas_site_when_display_export_banner_is_set
    @controller = create_controller UsersController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin
    unpaid = LicenseStatus.new(valid: true, trial: true, paid: false, max_active_full_users: 6)
    MingleConfiguration.overridden_to(new_buy_process: true, multitenancy_mode: true) do
      Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
      get :index
      assert_select '#trial_count_down', :count => 1
      MingleConfiguration.overridden_to(display_export_banner: true) do
        get :index
        assert_select '#trial_count_down', :count => 0
      end
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end


  def test_should_not_show_downgrade_lightbox_for_unpaid_saas_site
    @controller = create_controller UsersController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin
    unpaid = LicenseStatus.new(valid: false, trial: true, paid: false)
    MingleConfiguration.overridden_to(new_buy_process: true, multitenancy_mode: true) do
      Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
      get :index
      assert @response.body.match(/It looks like your 30 day trial has ended\./)
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  def test_should_not_show_downgrade_lightbox_for_unpaid_saas_site_when_display_export_banner_is_set
    @controller = create_controller UsersController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin
    unpaid = LicenseStatus.new(valid: false, trial: true, paid: false)
    MingleConfiguration.overridden_to(new_buy_process: true, multitenancy_mode: true, display_export_banner: true) do
      Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
      get :index
      assert_nil @response.body.match(/It looks like your 30 day trial has ended\./)
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  def test_should_not_show_buy_link_when_it_is_buying_status
    @controller = create_controller UsersController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin
    get :index
    assert_select '#buy', :count => 0
    unpaid = LicenseStatus.new(:valid => true, :trial => true, :paid => false)
    buying = LicenseStatus.new(:valid => true, :trial => true, :paid => false, :buying => true)
    MingleConfiguration.with_multitenancy_mode_overridden_to('true') do
      MingleConfiguration.with_new_buy_process_overridden_to('true') do
        Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
        get :index
        assert_select '#buy', :count => 1
        Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, buying)
        get :index
        assert_select '#buy', :count => 0
      end
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  def test_should_not_show_count_down_when_set_password
    @controller = create_controller ProfileController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    new_user = create_user! :login => 'new_person'
    get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
    assert_response :success

    assert_select '#trial_count_down', :count => 0
    unpaid = LicenseStatus.new(:valid => true, :trial => true, :paid => false, :max_active_full_users => 15)
    buying = LicenseStatus.new(:valid => true, :trial => true, :paid => false, :buying => true, :max_active_full_users => 15)
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to('true') do
      MingleConfiguration.with_multitenancy_mode_overridden_to('true') do
        MingleConfiguration.with_new_buy_process_overridden_to('true') do
          assert_nil SaasTos.first
          Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, unpaid)
          get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
          assert_response :success

          assert_select '#trial_count_down', :count => 0
          Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, buying)
          get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
          assert_response :success
          assert_select '#trial_count_down', :count => 0
        end
      end
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  def test_should_show_different_title_on_buy_button_based_max_active_user_number

    @controller = create_controller UsersController, :own_rescue_action => true
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    login_as_admin

    Cache.put(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY, LicenseStatus.new(:valid => true, :trial => true, :paid => false, :trial_info => 'hello'))
    MingleConfiguration.with_multitenancy_mode_overridden_to('true') do
      get :index
      assert_select 'a[title="hello"]', :count => 0
      MingleConfiguration.with_new_buy_process_overridden_to('true') do
        get :index
        assert_select 'a[title="hello"]', :count => 1
      end
    end
  ensure
    Cache.delete(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  def test_should_not_redirect_to_license_warning_if_license_is_already_expired
    Clock.fake_now(:year => 2008, :month => 7, :day => 31)
    expired_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-30', :max_active_users => 100}.to_query
    CurrentLicense.register!(expired_key, 'Funky Worm')
    @controller.send(:check_license_expiration)
    assert_response :success
  end

  def test_should_redirect_to_license_warning_when_user_has_not_seen_the_warning_and_license_is_expiring_soon
    Clock.fake_now(:year => 2008, :month => 7, :day => 5)
    expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100}.to_query
    CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
    @controller.send(:check_license_expiration)
    assert_redirected_to :controller => :license, :action => :warn
  end

  def test_should_not_redirect_to_license_warning_on_saas_for_unpaid_license_when_license_is_expiring_soon
    Clock.fake_now(:year => 2008, :month => 7, :day => 5)
    MingleConfiguration.with_multitenancy_mode_overridden_to(true) do
      expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100, :paid => false}.to_query
      CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
      @controller.send(:check_license_expiration)
      assert_response :success
    end
  end

  def test_should_not_redirect_to_license_warning_when_license_is_expiring_soon_but_user_has_already_dismissed_warning
    Clock.fake_now(:year => 2008, :month => 7, :day => 5)
    @controller.session['license_expiration_warning_dismissed'] = true
    expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100}.to_query
    CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
    @controller.send(:check_license_expiration)
    assert_response :success
  end

  def test_call_to_api_should_not_redirect_to_license_warning_when_license_is_expiring_soon
    Clock.fake_now(:year => 2008, :month => 7, :day => 5)
    expiring_soon_license_key = {:licensee => 'Funky Worm', :expiration_date => '2008-07-31', :max_active_users => 100}.to_query
    CurrentLicense.register!(expiring_soon_license_key, 'Funky Worm')
    @controller.request.request_uri = '/api/v2/something.xml'
    @controller.send(:check_license_expiration)
    assert_response :success

    @controller.request.request_uri = '/api/v2/something.xml?mql=number=1'
    @controller.send(:check_license_expiration)
    assert_response :success
  end

  def test_should_not_redirect_to_license_warning_when_license_is_not_expiring_soon
    Clock.fake_now(:year => 2008, :month => 7, :day => 5)
    future_license_key = {:licensee => 'Funky Worm', :expiration_date => '2088-07-31', :max_active_users => 100}.to_query
    CurrentLicense.register!(future_license_key, 'Funky Worm')
    @controller.send(:check_license_expiration)
    assert_response :success
  end

  def test_should_display_500_on_database_connection_timeout
    exception = ActiveRecord::ConnectionTimeoutError.new
    exception.set_backtrace([''])
    @controller.rescue_action_in_public(exception)
    assert_response 500
  end

  def test_all_response_should_have_x_frame_options_set_to_sameorigin
    @controller = create_controller(ProjectsController)
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    login_as_admin

    get :index
    assert_response :ok

    assert_equal 'SAMEORIGIN', @response.headers['X-Frame-Options']
  end

  def test_all_response_should_have_security_headers_set
      @controller = create_controller(ProjectsController)
      @request = ActionController::TestRequest.new
      @response = ActionController::TestResponse.new

      login_as_admin

      get :index
      assert_response :ok

      assert_equal 'NOSNIFF', @response.headers['X-CONTENT-TYPE-OPTIONS']
      assert_equal 'max-age=16070400; includeSubDomains', @response.headers['Strict-Transport-Security']
      assert_equal '1; mode=block', @response.headers['X-XSS-Protection']
  end

  def test_all_response_should_have_csp_headers_set
    @controller = create_controller(ProjectsController)
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    expected_csp_policy  = "default-src 'self'; script-src 'unsafe-inline' 'unsafe-eval' 'self' https://*.pingdom.net"+
    " cdn.mxpnl.com https://cdn.firebase.com https://*.firebaseio.com https://*.cloudfront.net"+
    " https://s3.amazonaws.com platform.twitter.com; connect-src 'self' https://s3-us-west-1.amazonaws.com"+
    " https://*.s3-us-west-1.amazonaws.com wss://*.firebaseio.com https://*.cloudfront.net https://api.mixpanel.com https://*.pingdom.net;"+
    " img-src * 'self' data: blob:; style-src 'unsafe-inline' 'self' https://*.cloudfront.net; font-src 'self'"+
    " https://*.cloudfront.net data: themes.googleusercontent.com; frame-src 'self' https://www.google.com maps.google.com"+
    " calendar.google.com https://*.firebaseio.com https://*.thoughtworks.com platform.twitter.com; frame-ancestors 'self';"
    MingleConfiguration.with_csp_overridden_to(true) do
      login_as_admin

      get :index
      assert_response :ok
      assert_equal expected_csp_policy, @response.headers['Content-Security-Policy']
      assert_equal @response.headers['Content-Security-Policy'], @response.headers['X-Content-Security-Policy']
    end
  end


  def test_session_options_has_secure_set_to_ensure_session_cookie_encrypted
    login_as_admin
    get :index
    assert_response :redirect
    assert_false @request.session_options[:secure]
  end

  def test_site_activity_should_not_track_system_user_and_anonymous_user
    @controller = create_controller(ProjectsController)
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    logout_as_nil
    get :index
    assert_false(CACHE.store.keys.any?{|k| k =~ /site_activity/})

    @admin = login_as_admin
    @admin.update_attribute(:system, true)

    get :index
    assert_response :ok
    assert_false(CACHE.store.keys.any?{|k| k =~ /site_activity/})

    @admin.update_attribute(:system, false)
    get :index
    assert_response :ok
    assert Cache.get("site_activity_#{@admin.id}")
  end

  def prepare
    @request.recycle!
    @response.recycle!
    @response.template = ActionView::Base.new(@controller.class.view_paths, {}, self)
    @response.template.extend(ApplicationHelper)
    @response.template.instance_eval do
      def protect_against_forgery?
        false
      end
    end

    @controller.instance_variable_set(:@template, @response.template)
    @controller.instance_variable_set(:@url, FakeUrlWriter.new)
    def @controller.flash; @flash ||= {} end
    def @controller.session; @session ||= {} end
    @controller.action_name = ""
  end
end
