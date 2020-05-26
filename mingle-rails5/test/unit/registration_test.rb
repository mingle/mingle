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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class RegistrationTest < ActiveSupport::TestCase

  def setup
    create(:user, admin: true, login: :admin)
  end

  def test_license_registraion_should_know_if_maximum_number_of_full_users_has_been_reached
    register_license
    assert_false CurrentLicense.registration.max_active_full_users_reached?

    register_license(:max_active_users => User.activated_full_users)
    assert CurrentLicense.registration.max_active_full_users_reached?

    build(:light_user).save validate:false
    assert CurrentLicense.registration.max_active_full_users_reached?
  end

  def test_license_should_be_valid_when_the_max_light_users_have_been_reached_but_max_full_users_not_reached
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)

    create(:light_user)
    assert CurrentLicense.status.valid?

    build(:light_user).save validate:false
    CurrentLicense.clear_cached_license_status!
    assert_false CurrentLicense.status.valid?
  end

  def test_max_activated_light_user_should_not_be_reached_when_max_light_users_reached_but_full_users_still_available
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)
    assert !CurrentLicense.registration.max_active_light_users_reached?
    assert !CurrentLicense.registration.max_active_full_users_reached?
    create(:light_user)
    assert CurrentLicense.registration.max_active_light_users_reached?
    assert CurrentLicense.registration.max_active_full_users_reached?
  end

  def test_should_know_how_many_full_user_seats_are_currently_used_as_light_users
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)
    create(:light_user)
    assert_equal 1, CurrentLicense.registration.full_users_used_as_light
  end

  def test_should_know_how_many_full_user_seats_are_currently_used_as_light_users_when_no_light_users_active
    register_license(:max_light_users => User.activated_light_users + 1, :max_active_users => User.activated_full_users)
    assert_equal 0, CurrentLicense.registration.full_users_used_as_light
  end

  def test_should_know_if_full_users_used_as_light
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)
    create(:light_user)
    assert CurrentLicense.registration.full_users_used_as_light?
  end

  def test_should_be_no_warning_when_license_is_not_full
    register_license
    assert_nil CurrentLicense.registration.license_warning_message
  end

  def test_should_warn_when_no_more_full_users_can_be_added
    register_license(:max_active_users => User.activated_full_users)
    assert_not_nil CurrentLicense.registration.license_warning_message
  end

  def test_should_warn_when_no_more_light_users_and_no_more_full_users_can_be_added
    create(:light_user)
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users)
    assert_not_nil CurrentLicense.registration.license_warning_message
  end

  def test_should_know_if_license_is_enterprise
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    assert !CurrentLicense.registration.enterprise?
    register_license(:product_edition => Registration::ENTERPRISE)
    assert CurrentLicense.registration.enterprise?
  end

  def test_product_edition_defaults_to_non_enterprise_for_licenses_that_dont_know_about_product_edition
    CurrentLicense.register!({:product_edition => 'standard', :max_active_users => '1' ,:max_light_users => '1', :expiration_date => '2020-12-30', :allow_anonymous => false, :licensee => "tworker" }.to_query, "tworker")
    assert_equal Registration::DISPLAY_NAMES[Registration::NON_ENTERPRISE], CurrentLicense.registration.edition_display_name
    register_license(:product_edition => Registration::ENTERPRISE)
    assert_equal Registration::DISPLAY_NAMES[Registration::ENTERPRISE], CurrentLicense.registration.edition_display_name
  end

  def test_should_raise_error_if_you_try_to_initialize_with_nil_values
    assert_raises(RuntimeError) { Registration.new({}) }
  end

  def test_buy_tier_status
    reg = Registration.new({'max_active_users' => 1, 'expiration_date' => '2033-01-01'})
    assert_equal 10, reg.validate.buy_tier

    reg = Registration.new({'max_active_users' => 5, 'expiration_date' => '2033-01-01'})
    assert_equal 10, reg.validate.buy_tier

    reg = Registration.new({'max_active_users' => 10, 'expiration_date' => '2033-01-01'})
    assert_equal 10, reg.validate.buy_tier

    reg = Registration.new({'max_active_users' => 15, 'expiration_date' => '2033-01-01'})
    assert_equal 15, reg.validate.buy_tier

    reg = Registration.new({'max_active_users' => 25, 'expiration_date' => '2033-01-01'})
    assert_equal 25, reg.validate.buy_tier

    reg = Registration.new({'max_active_users' => 49, 'expiration_date' => '2033-01-01'})
    assert_equal 50, reg.validate.buy_tier

    reg = Registration.new({'max_active_users' => 51, 'expiration_date' => '2033-01-01'})
    assert_equal 100, reg.validate.buy_tier

    reg = Registration.new({'max_active_users' => 200, 'expiration_date' => '2033-01-01'})
    assert_equal 200, reg.validate.buy_tier
  end

  def test_full_user_licenses_left_returns_the_number_of_full_user_licenses_left
    register_license(:max_active_users => User.activated_full_users + 5)

    assert_equal 5, CurrentLicense.registration.full_user_licenses_left
  end

  def test_full_user_licenses_left_should_account_for_full_user_licenses_used_for_light_users
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)
    create(:light_user)

    assert_equal 0, CurrentLicense.registration.full_user_licenses_left
  end
end
