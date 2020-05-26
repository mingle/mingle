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

class LicenseStatus
#  include RoutingUrlHelper

  attr_accessor :days_remaining_before_expiration
  attr_reader :trial_info, :buy_tier, :max_active_full_users

  def initialize(options)
    # valid, allow_anonymous, enterprise, detail = [], expiring_soon=false, days_remaining_before_expiration=nil
    @valid = options[:valid]
    @detail = options[:detail] || []
    @allow_anonymous = options[:allow_anonymous]
    @enterprise = options[:enterprise]
    @expiring_soon = options[:expiring_soon]
    @days_remaining_before_expiration = options[:days_remaining_before_expiration]
    @trial = options[:trial]
    @paid = options[:paid]
    @trial_info = options[:trial_info]
    @expired_in_week = options[:expired_in_week]
    @max_active_full_users = options[:max_active_full_users].to_i
    @buy_tier = Registration::TIERS.find {|t| t >= @max_active_full_users} || Registration::TIERS.last
    @buying = options[:buying]
  end

  def days_left
    @days_remaining_before_expiration
  end

  def buying?
    @buying
  end

  def free_tier?
    @max_active_full_users <= Registration::TRIAL_USER_COUNT
  end

  def expired_in_week?
    @expired_in_week
  end

  def valid?
    return true unless RUBY_PLATFORM =~ /java/ || Rails.env.test?
    @valid
  end

  def invalid?
    !valid?
  end

  def paid?
    @paid
  end

  def trial?
    @trial
  end

  def allow_anonymous?
    @allow_anonymous
  end

  def enterprise?
    @enterprise
  end

  def detail
    @detail.join("\n")
  end

  def registration_page_link
    if User.current.admin? && FEATURES.active?('license_management')
      link = link_to_without_user_access("registration page", :controller => 'license', :action => 'show')
      "To register your valid Mingle license, please go to the #{link} for your Mingle instance."
    else
      ""
    end.html_safe
  end

  def expiring_soon?
    @expiring_soon == true
  end


end
