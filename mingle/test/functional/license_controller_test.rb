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

# Re-raise errors caught by the controller.
class LicenseController
  def generate_flash_error
    flash[:error] = "I am error message."
    redirect_to :action => 'show'
  end
end

class LicenseControllerTest < ActionController::TestCase
  def setup
    clear_license
    Clock.fake_now(:year => 2007, :month => 1, :day => 1)
    @controller = create_controller LicenseController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
  end

  def teardown
    Clock.reset_fake
  end

  # bug 1861
  def test_valid_license_should_not_be_overridden_by_bad_registration_data
    license_key = {:licensee => 'bobo', :expiration_date => '2100-12-30', :max_active_users => 1000, :max_light_users => 1000}.to_query
    post :update, :licensed_to  => 'bobo', :license_key => license_key
    follow_redirect
    assert CurrentLicense.status.valid?
    assert_equal license_key, CurrentLicense.license_key

    bogus_license_key = {:licensee => '', :expiration_date => '2100-12-30', :max_active_users => 1000}.to_query
    post :update, :licensed_to  => '', :license_key => bogus_license_key
    assert_error 'License data is invalid'
    assert CurrentLicense.status.valid?
    assert_equal license_key, CurrentLicense.license_key

    bogus_license_key2 = {:licensee => 'invalid', :expiration_date => '2100-12-30', :max_active_users => 1000}.to_query
    post :update, :licensed_to  => 'bogus_user', :license_key => bogus_license_key2
    assert_error 'License data is invalid'
    assert CurrentLicense.status.valid?
    assert_equal license_key, CurrentLicense.license_key
  end

  def test_license_status_should_be_updated_when_register_license_successful
    register_with_expired_license
    assert !CurrentLicense.status.valid?
    license_key = {:licensee => 'bobo', :expiration_date => '2100-12-30', :max_active_users => 1000, :max_light_users => 1000}.to_query

    post :update, :licensed_to  => 'bobo', :license_key => license_key
    assert_nil flash[:error]
    follow_redirect
    assert_notice 'License was registered successfully'
    assert CurrentLicense.status.valid?
  end

  def test_should_show_error_message_and_not_register_when_the_license_is_invalid
    post :update, :license_key => ''
    assert_invalid_license
    post :update, :license_key => 'Invalid license key'
    assert_invalid_license
    post :update, :licensed_to => 'invalid', :license_key => {:licensee => 'bobo', :expiration_date => '2100-12-30', :max_active_users => 1000}.to_query
    assert_invalid_license
  end

  def test_should_register_key_when_the_license_is_valid_but_it_is_expired
    post :update, :licensed_to => 'bobo', :license_key => {:licensee => 'bobo', :expiration_date => '2006-12-30', :max_active_users => 1000}.to_query
    follow_redirect
    assert_notice 'License was registered successfully'
    assert_info
  end

  def test_render_show_page_license_details_when_license_is_impossible
    # The intent of this test is to ensure that somebody updating Registration
    # also overrides the corresponding method on InvalidRegistration.
    License.first.update_attribute :license_key, 'abcdef'
    get :show
    assert_response :success
  end

  def test_should_not_replace_application_error_when_the_license_is_invalid
    get :show
    assert_info
    post :generate_flash_error
    follow_redirect
    assert_error "I am error message."
  end

  def test_should_show_all_info_when_the_license_is_standard_license
    register_license(:max_light_users => 888, :max_active_users => 1000, :allow_anonymous => true, :expiration_date => '2008-01-01', :licensee => 'boo')

    get :show

    assert_select 'li[name=licensed-to] span', :text => 'boo'
    assert_select 'li[name=expiration-date] span', :text => '2008-01-01'
    assert_select 'li[name=max-active-users] span', :text => '1000'
    assert_select 'li[name=allow-anonymous] span', :text => 'true'
    assert_select 'li[name=max-light-users] span', :text => '888'
    assert_select 'li[name=product-edition] span', :text => Registration::DISPLAY_NAMES[Registration::ENTERPRISE]
  end

  def test_should_show_non_enterprise_when_non_enterprise_edition
    register_license(:max_light_users => 888, :max_active_users => 1000, :allow_anonymous => true, :expiration_date => '2008-01-01', :licensee => 'boo', :product_edition => Registration::NON_ENTERPRISE)

    get :show

    assert_select 'li[name=product-edition] span', :text => Registration::NON_ENTERPRISE
  end

  def test_logo_should_link_to_projects_when_non_enterprise
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    get :show

    assert_select 'a.logo[href=/projects]', :count => 1
    assert_no_tag 'a.logo[href=/programs]'
  end

  def test_logo_should_link_to_programs_when_enterprise
    register_license(:product_edition => Registration::ENTERPRISE)
    get :show

    assert_select 'a.logo[href=/programs]', :count => 1
    assert_no_tag 'a.logo[href=/projects]'
  end

  def test_should_show_current_license_usage
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)
    create_user_without_validation(:light => true)

    get :show
    assert_select 'li[name=current-active-users] span', :text => User.activated_full_users.to_s
    assert_select 'li[name=current-light-users] span', :text => '1'
    assert_select 'span[name=borrowed]', :text => '1'
  end

  #6132
  def test_should_not_show_borrowed_status_when_license_is_invalid
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users)
    create_user_without_validation(:light => true)

    get :show
    assert_select 'span[name=borrowed]', false
  end

  def test_should_show_current_license_usage_when_full_users_used_as_light
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)

    get :show

    assert_select 'li[name=current-active-users] span', :text => User.activated_full_users.to_s
    assert_select 'li[name=current-light-users] span', :text => User.activated_light_users.to_s
  end

  def test_should_show_dismissable_warning
    Clock.fake_now(:year => 2007, :month => 1, :day => 1)
    CurrentLicense.register!({:licensee => 'expired', :expiration_date => '2007-1-2', :max_active_users => 1000}.to_query, 'expired')
    get :warn
    assert_response :success
    assert_select 'input[type=submit][value="Remind Me Later"]'
    assert_select 'h2', :text => /1 day/
  end

  def test_should_know_if_soon_expiriation_warning_has_been_dismissed
    post :dismiss_expiration_warning
    assert session['license_expiration_warning_dismissed']
  end

  def test_should_redirect_to_previously_requested_url_when_expiriation_warning_has_been_dismissed
    target_url = { :controller => 'users', :action => 'list' }
    session['return-to'] = target_url
    post :dismiss_expiration_warning
    assert_redirected_to target_url
  end

  def test_should_redirect_to_default_if_no_target_provided_when_expiriation_warning_has_been_dismissed
    post :dismiss_expiration_warning
    assert_redirected_to root_path
  end

  def test_ask_for_upgrade_responds_with_thanks_message_html
    post :ask_for_upgrade
    assert_response :success
    assert_select 'h1', 'Thanks!'
  end

  def test_ask_for_upgrade_sends_email_to_studios_email
    post :ask_for_upgrade
    email = ActionMailer::Base.deliveries.last
    assert_match /more users/, email.body
  end

  def test_clear_cached_status_should_clear_cached_status
    CurrentLicense.status
    assert Cache.get(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)

    get :clear_cached_license_status

    assert_response :success
    assert_nil Cache.get(CurrentLicense::LICENSE_STATUS_MEMCACHE_KEY)
  end

  private
  def register_with_expired_license
    expired_license_key = {:licensee => 'expired', :expiration_date => '2007-12-30', :max_active_users => 1000}.to_query
    CurrentLicense.register!(expired_license_key, 'expired')
    Clock.fake_now(:year => 2008, :month => 1, :day => 1)
  end

  def assert_invalid_license
    assert_error 'License data is invalid'
    assert_nil CurrentLicense.license_key
  end
end
