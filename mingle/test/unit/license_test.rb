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

class LicenseTest < ActiveSupport::TestCase

  def setup
    User.find(:all).each(&:destroy_without_callbacks)
    create_user!
    Clock.fake_now(:year => 2008, :month => 7, :day => 12)
    clear_license
  end

  def teardown
    Clock.reset_fake
    FEATURES.activate("db_licensing")
    CurrentLicense.clear_cached_registration!
  end

  def test_current_license_should_be_registered_license_when_the_user_is_registered
    assert_kind_of InvalidRegistration, CurrentLicense.registration
    assert CurrentLicense.register!(license_key, licensed_to).valid?
    assert_kind_of Registration,  CurrentLicense.registration
  end

  def test_register_syncs_with_profile_server
    MingleConfiguration.with_app_namespace_overridden_to('osito') do
      @http_stub = HttpStub.new

      ProfileServer.configure({:url => "https://profile_server"}, @http_stub)

      CurrentLicense.register!(license_key, licensed_to)

      put_data = JSON.parse(@http_stub.last_request.body)
      assert_equal license_key_hash['max_active_users'], put_data['max_active_full_users']
      assert_equal license_key_hash['max_light_users'], put_data['max_active_light_users']
      assert_equal license_key_hash['product_edition'], put_data['product_edition']
      assert_equal license_key_hash['allow_anonymous'], put_data['allow_anonymous']
      assert_equal license_key_hash['expiration_date'], put_data['subscription_expires_on']
    end
  end

  def test_registration_when_profile_server_not_setup_returns_temp_registration
    FEATURES.deactivate("db_licensing")
    registration = CurrentLicense.registration
    assert_equal CurrentLicense.temp_registration.expiration_date, registration.expiration_date
  end

  def test_can_register_a_license_key_when_db_licensing_is_disabled
    FEATURES.deactivate("db_licensing")
    status = CurrentLicense.register!(license_key, licensed_to)
    assert status.valid?
  end

  def test_registration_should_be_retrieved_from_profile_server_when_db_licensing_is_deactivated
    MingleConfiguration.with_app_namespace_overridden_to('osito') do
      @http_stub = HttpStub.new
      ProfileServer.configure({:url => "https://profile_server"}, @http_stub)

      response = {
        "name" => "parsley",
        "subscription_expires_on" => "2015-05-06",
        "allow_anonymous" => true,
        "product_edition" => "Mingle Enterprise",
        "max_active_full_users" => 77,
        "max_active_light_users" => 66,
        "users_url" => "https://profile_server/organizations/parsley/users.json",
        "created_at" => Time.now.to_s,
        'trial?' => false,
        'paid?' => true,
        'buying?' => false
      }
      @http_stub.register_get_response('https://profile_server/organizations/osito.json', [200, response.to_json])


      FEATURES.deactivate("db_licensing")
      registration = CurrentLicense.registration
      assert_equal 77, registration.max_active_full_users
      assert_equal 66, registration.max_active_light_users
      assert registration.allow_anonymous?
      assert_equal Date.parse('2015-05-06'), registration.expiration_date
      assert registration.enterprise?
      assert_nil registration.licensed_to

      assert_equal false, registration.trial?
      assert_equal true, registration.paid?
      assert_equal false, registration.buying?
    end
  end

  def test_registration_should_be_cached_in_a_thread_local
    status = CurrentLicense.register!(license_key, licensed_to)
    assert status.valid?
    reg = CurrentLicense.registration
    assert_equal reg, ThreadLocalCache.get(:current_license_registration)
    ThreadLocalCache.set(:current_license_registration, "threadlocal")
    assert_equal "threadlocal", CurrentLicense.registration
  end


  def test_refresh_status_should_not_use_cached_registration
    CurrentLicense.register!(license_key, licensed_to)
    assert CurrentLicense.refresh_status.valid?
    ThreadLocalCache.set(:current_license_registration, InvalidRegistration.new("invalid"))
    assert CurrentLicense.refresh_status.valid?
  end

  def test_license_key_should_be_nil_when_db_licensing_is_deactivated
    FEATURES.deactivate("db_licensing")
    assert_nil CurrentLicense.license_key
  end

  def test_registration_should_be_invalid_if_the_license_key_is_invalid
    status = CurrentLicense.register!('invalid license key',licensed_to)
    assert !status.valid?
    assert_equal "The license data is invalid", status.detail
  end

  def test_trial_should_be_true_for_a_status_from_license_with_5_seats
    status = CurrentLicense.register!(license_key(:max_active_users => 5), licensed_to)
    assert status.trial?
  end

  def test_read_trial_status_from_profile_server
    MingleConfiguration.with_app_namespace_overridden_to('osito') do
      @http_stub = HttpStub.new
      ProfileServer.configure({:url => "https://profile_server"}, @http_stub)

      response = {
        "name" => "parsley",
        "subscription_expires_on" => "2015-05-06",
        "allow_anonymous" => true,
        "product_edition" => "Mingle Enterprise",
        "max_active_full_users" => 77,
        "max_active_light_users" => 66,
        "users_url" => "https://profile_server/organizations/parsley/users.json",
        "trial?" => 'false'
      }
      @http_stub.register_get_response('https://profile_server/organizations/osito.json', [200, response.to_json])


      FEATURES.deactivate("db_licensing")
      registration = CurrentLicense.registration
      assert !registration.trial?
    end
  end

  def test_trial_should_be_false_for_a_status_from_license_with_6_seats
    status = CurrentLicense.register!(license_key(:max_active_users => 6), licensed_to)
    assert_false status.trial?
  end

  def test_registration_should_be_invalid_if_activated_users_more_than_the_max_activate_users
    (1..(10 - User.activated_full_users)).each{ create_user_without_validation }
    assert CurrentLicense.register!(license_key, licensed_to).valid?
    create_user_without_validation
    status = CurrentLicense.register!(license_key, licensed_to)
    assert status.valid?
    assert CurrentLicense.status.detail.include?("You've reached the maximum number of users for your site.")
  end

  def test_registration_should_be_invalid_if_license_date_is_expiration
    assert CurrentLicense.register!(license_key, licensed_to).valid?
    Clock.fake_now(:year => 2008, :month => 7, :day => 14)
    status = CurrentLicense.register!(license_key, licensed_to)
    assert status.valid?
    assert CurrentLicense.status.detail.include?("The license for this instance has expired.")
  end

  def test_should_know_if_license_is_within_30_days_of_expiration_but_not_expired
    Clock.fake_now(:year => 2008, :month => 7, :day => 1)
    assert !CurrentLicense.register!(license_key(:expiration_date => '2008-08-1'), licensed_to).expiring_soon?
    assert CurrentLicense.register!(license_key(:expiration_date => '2008-07-31'), licensed_to).expiring_soon?
    assert CurrentLicense.register!(license_key(:expiration_date => '2008-07-5'), licensed_to).expiring_soon?
    assert !CurrentLicense.register!(license_key(:expiration_date => '2008-07-1'), licensed_to).expiring_soon?
  end

  def test_should_know_days_remaining_before_expiration
    Clock.fake_now(:year => 2008, :month => 7, :day => 30)
    assert_equal 1, CurrentLicense.register!(license_key(:expiration_date => '2008-07-31'), licensed_to).days_remaining_before_expiration
    assert_equal 0, CurrentLicense.register!(license_key(:expiration_date => '2008-07-30'), licensed_to).days_remaining_before_expiration
    assert_equal 0, CurrentLicense.register!(license_key(:expiration_date => '2008-07-29'), licensed_to).days_remaining_before_expiration
  end

  def test_license_expiration_message_should_include_anonymous_projects_info
    register_expiration_license_with_allow_anonymous
    assert !CurrentLicense.status.valid?
    assert CurrentLicense.status.detail.include?("Any anonymous access enabled projects will be inaccessible")
  end

  def test_license_valid_with_licensee
    assert CurrentLicense.register!(license_key, licensed_to).valid?
    status = CurrentLicense.register!(license_key, 'invalid licensee')
    assert !status.valid?
    assert_equal 'License data is invalid.', status.detail
    status = CurrentLicense.register!('', '')
    assert !status.valid?
  end

  def test_allow_anonymous_is_false_when_it_is_not_included_on_the_license
    key = license_key_hash
    key.delete(:allow_anonymous)
    key = key.to_query

    assert CurrentLicense.register!(key, licensed_to).valid?
    assert !CurrentLicense.registration.allow_anonymous?

    key_with_anonymous_access = license_key_hash.merge(:allow_anonymous => true).to_query
    assert CurrentLicense.register!(key_with_anonymous_access, licensed_to).valid?
    assert CurrentLicense.registration.allow_anonymous?
  end

  def test_invalid_registration_should_not_allow_anonymous_access
    assert !InvalidRegistration.new("invalid").allow_anonymous?
  end

  def test_license_defaults_to_non_enterprise
    CurrentLicense.register!({:type => 'standard', :max_active_users => '1' ,:max_light_users => '1', :expiration_date => '2020-12-30', :allow_anonymous => false, :licensee => "tworker" }.to_query, "tworker")
    assert !CurrentLicense.status.enterprise?
    register_license(:product_edition => Registration::ENTERPRISE)
    assert CurrentLicense.status.enterprise?
  end

  def test_should_still_be_enterprise_when_license_is_expired
    CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
    Clock.fake_now(:year => 2008, :month => 7, :day => 14)
    assert CurrentLicense.status.enterprise?
  end

  def test_trial_info
    status = CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
    assert_equal "Your trial will end on 2008-07-13", status.trial_info

    status = CurrentLicense.register!(license_key_hash.merge(:max_active_users => 5).to_query, licensed_to)
    assert_equal "You're using Mingle 5-free users", status.trial_info
  end

  private

  def license_key_hash
    {:licensee =>licensed_to, :max_active_users => '10' ,:expiration_date => '2008-07-13', :max_light_users => '8', :product_edition => Registration::NON_ENTERPRISE}
  end

  def license_key(options = {})
    license_key_hash.merge(options).to_query
  end

  def licensed_to
    'barbobo'
  end

end
