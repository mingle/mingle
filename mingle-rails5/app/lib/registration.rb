# -*- coding: utf-8 -*-

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

class Registration
  ENTERPRISE = 'Mingle Enterprise'
  NON_ENTERPRISE = 'Mingle'
  DISPLAY_NAMES = { ENTERPRISE => 'Mingle Plus', NON_ENTERPRISE => NON_ENTERPRISE }

  TIERS = [10, 15, 25, 50, 100, 200]

  TRIAL_USER_COUNT = 5

  attr_reader :max_active_full_users, :max_active_light_users, :expiration_date, :edition, :licensed_to

  def initialize(opts)
    @error_messages = []
    @allow_anonymous = opts['allow_anonymous']
    @max_active_full_users = required_key('max_active_users', opts).to_i
    @max_active_light_users = opts['max_light_users'].to_i
    @expiration_date = Date.strptime(required_key('expiration_date', opts))
    @edition = opts['product_edition'] || NON_ENTERPRISE
    @licensed_to = opts['licensee']
    @trial = opts['trial'].blank? ? max_active_full_users <= TRIAL_USER_COUNT : opts['trial']
    @trial = @trial == 'true' || @trial == true
    @paid = opts['paid'] == 'true' || opts['paid'] == true
    @buying = opts['buying'] == 'true' || opts['buying'] == true
    @company_name = opts['company_name']
  end

  def buying?
    @buying
  end

  def paid?
    @paid
  end

  def trial?
    @trial
  end

  def allow_anonymous?
    @allow_anonymous == 'true'
  end

  def edition_display_name
    matched_edition = [ENTERPRISE, NON_ENTERPRISE].find { |edition| edition == @edition }
    DISPLAY_NAMES[(matched_edition.nil? ? NON_ENTERPRISE : matched_edition)]
  end

  def enterprise?
    @edition == ENTERPRISE
  end

  def validate_with_licensee(licensed_to)
    status(check_licensee?(licensed_to))
  end

  def validate
    status(check_max_active_user? && check_expiration_date? && check_max_active_light_user?)
  end

  def max_active_full_users_reached?
    full_user_licenses_left <= 0
  end

  def full_user_licenses_left
    max_active_full_users - full_users_used_as_light - User.activated_full_users
  end

  def full_users_used_as_light
    full_users_used_as_light? ? User.activated_light_users - max_active_light_users : 0
  end

  def full_users_used_as_light?
    User.activated_light_users > max_active_light_users
  end

  def max_active_light_users_reached?
    User.activated_light_users >= max_active_light_users + remaining_full_users
  end

  def license_warning_message
    if max_active_full_users_reached?
      "You've reached the maximum number of users for your site. #{obtain_new_license}"
    end
  end

  def company_name
    @company_name
  end

  private

  def required_key(key, hash)
    raise "#{key} is required" if hash[key].blank?
    hash[key]
  end

  def obtain_new_license
    "Please get in touch with us for more at <a href='mailto:studios@thoughtworks.com'>studios@thoughtworks.com</a>."
  end

  def status(valid)
    LicenseStatus.new(:valid => valid,
                      :allow_anonymous => allow_anonymous?,
                      :enterprise => enterprise?,
                      :detail => @error_messages,
                      :expiring_soon => expiring_soon?,
                      :days_remaining_before_expiration => days_remaining_before_expiration,
                      :trial => trial?,
                      :paid => paid?,
                      :trial_info => trial_info,
                      :expired_in_week => expired_in_1_week?,
                      :max_active_full_users => max_active_full_users,
                      :buying => buying?)
  end

  def trial_info
    max_active_full_users <= 5 ? "You're using Mingle 5-free users" : "Your trial will end on #{expiration_date}"
  end

  def days_remaining_before_expiration
    [(expiration_date - Clock.now.to_date).to_i, 0].max
  end

  def expired_in_1_week?
    days_remaining_before_expiration <= 7
  end

  def expiring_soon?
    (1..30).include?(days_remaining_before_expiration)
  end

  def check_licensee?(licensee)
    check_condition("License data is invalid.") do
      !licensee.blank? && licensee.strip == licensed_to
    end
  end

  def check_max_active_user?
    check_condition("You've reached the maximum number of users for your site. #{obtain_new_license}") do
      max_active_full_users >= User.activated_full_users
    end
  end

  def check_max_active_light_user?
    check_condition("You've reached the maximum number of users for your site. #{obtain_new_license}") do
      max_active_light_users + remaining_full_users >= User.activated_light_users
    end
  end

  def check_expiration_date?
    check_condition(expiration_message) do
      expiration_date > Clock.today
    end
  end

  def expiration_message
    "This instance of Mingle is in violation of the registered license. The license for this instance has expired. #{while_the_license_is_in_violation} Please get in touch with us at <a href='mailto:studios@thoughtworks.com'>studios@thoughtworks.com</a>."
  end


  def check_condition(error, &block)
    @error_messages << error unless yield
    yield
  end

  def while_the_license_is_in_violation
    CurrentLicense.while_the_license_is_in_violation
  end

  def remaining_full_users
    max_active_full_users - User.activated_full_users
  end

end
