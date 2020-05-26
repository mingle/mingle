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

class InvitesHelperTest < ActiveSupport::TestCase
  include ActionView::Helpers::TextHelper
  include InvitesHelper

  def setup
    @project = first_project
  end

  def test_invite_link_enabled_for_trial_sites_with_activated_projects
    register_license(:trial => true)
    @project.activate
    login_as_member
    assert invites_enabled?
  end

  def test_invite_link_disabled_when_no_project_activated
    register_license(:trial => false)
    assert_false invites_enabled?
  end

  def test_invite_link_enabled_for_mingle_admins_for_paying_sites_when_user_count_under_limit_and_smtp_configured
    @project.activate
    login_as_admin
    register_license(:trial => false)
    assert invites_enabled?
  end

  def test_invite_link_enabled_for_project_admins_for_paying_sites_when_user_count_under_limit_and_smtp_configured
    @project.activate
    login_as_proj_admin
    register_license(:trial => false)
    assert invites_enabled?
  end

  def test_invite_link_disabled_for_non_admin_members_for_paying_sites_and_smtp_configured
    @project.activate
    login_as_member
    register_license(:trial => false)
    assert_false invites_enabled?
  end

  def test_invite_link_disabled_for_admins_on_other_projects_and_smtp_configured
    other_project_admin= create_user!
    with_new_project do |other_project|
      other_project.add_member(other_project_admin, :project_admin)
    end
    @project.activate
    login(other_project_admin)
    register_license(:trial => false)
    assert_false invites_enabled?
  end

  def test_invite_link_disabled_when_readonly_project_member_is_current_user
    readonly_user = create_user!
    @project.add_member(readonly_user, :readonly_member)
    login(readonly_user)

    assert_false invites_enabled?
  end

  def test_invite_link_disabled_when_no_smtp_configured
    @project.activate
    login_as_proj_admin
    register_license(:trial => false)
    SmtpConfiguration.class_eval do
      def self.configured_with_always_disabled?
        false
      end

      class << self
        alias_method_chain :configured?, :always_disabled
      end
    end

    assert_false SmtpConfiguration.configured?
    assert_false invites_enabled?

  ensure
    SmtpConfiguration.class_eval do
      class << self
        alias_method :configured?, :configured_without_always_disabled?
      end
    end
  end

  def test_should_disable_invites_button_for_paid_sites_when_they_are_out_of_licenses
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do

      register_license(:paid => true, :max_active_users => User.activated_full_users)

      assert disable_invites_button?
    end
  end

  def test_should_not_disable_invites_button_for_paid_sites_when_they_have_enough_licenses
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do

      register_license(:paid => true, :max_active_users => User.activated_full_users + 2)

      assert_false disable_invites_button?
    end
  end

  def test_should_not_disable_invites_button_for_installer_version
    MingleConfiguration.overridden_to(:multitenancy_mode => nil, :saas_env => nil) do

      register_license(:paid => true, :max_active_users => User.activated_full_users)

      assert_false disable_invites_button?
    end
  end

  def test_should_not_disable_invites_button_for_trial_sites_when_they_have_enough_licenses
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do

      register_license(:paid => false, :max_active_users => User.activated_full_users + 2)

      assert_false disable_invites_button?
    end
  end

  def test_should_disable_invites_button_for_trial_sites_when_they_are_out_of_licenses
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do

      @project.activate
      login_as_admin
      register_license(:paid => false, :max_active_users => User.activated_full_users)

      assert_false disable_invites_button?
    end
  end

  def test_should_not_display_low_on_licenses_alaert_for_trial_sites
    register_license(:trial => true)

    assert_false show_low_on_licenses_alert?
  end

  def test_should_not_display_low_on_licenses_alert_for_installer_version
    MingleConfiguration.overridden_to(:multitenancy_mode => nil, :saas_env => nil) do
      register_license(:paid => true)

      assert_false show_low_on_licenses_alert?
    end
  end

  def test_should_not_display_low_on_licenses_alert_when_not_on_any_project_page_on_paid_sites
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do
      register_license(:paid => true)

      assert_false show_low_on_licenses_alert?
    end
  end

  def test_should_not_display_low_on_licenses_alert_for_non_admin_users_on_paid_sites
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do

      @project.activate
      login_as_member
      register_license(:paid => true)

      assert_false show_low_on_licenses_alert?
    end
  end

  def test_should_not_display_low_on_licences_alert_for_admins_on_paid_sites_having_more_than_5_licenses_left
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do
      @project.activate
      login_as_admin
      register_license(:paid => true)

      assert_false show_low_on_licenses_alert?
    end
  end

  def test_should_not_display_low_on_licenses_alert_for_admins_on_paid_sites_having_and_sso_enabled_more_than_5_licenses_left
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test', :sso_enabled => 'true') do
      @project.activate
      login_as_admin
      register_license(:paid => true)

      assert_false show_low_on_licenses_alert?
    end
  end

  def test_should_display_low_on_licenses_alert_for_admins_on_paid_sites_having_less_than_5_licenses_left
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do
      @project.activate
      login_as_admin
      register_license(:paid => true, :max_active_users => User.activated_full_users + 2)

      assert show_low_on_licenses_alert?
    end
  end

  def test_should_display_low_on_licenses_alert_for_admins_on_paid_sites_having_and_sso_enabled_less_than_5_licenses_left
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test', :sso_enabled => 'true') do
      @project.activate
      login_as_admin
      register_license(:paid => true, :max_active_users => User.activated_full_users + 2)

      assert show_low_on_licenses_alert?
    end
  end

  def test_license_alert_message_should_have_count_when_there_are_remaining_licenses
    register_license(:paid => true, :max_active_users => User.activated_full_users + 2)

    assert_equal '2 licenses left', license_alert_message
  end

  def test_license_alert_message_should_return_no_license_left_when_all_licenses_have_been_consumed
    register_license(:paid => true, :max_active_users => User.activated_full_users)

    assert_equal 'No licenses left', license_alert_message
  end

  def test_license_alert_message_should_return_no_license_left_when_users_are_more_than_licenses
    register_license(:paid => true, :max_active_users => User.activated_full_users - 20)

    assert_equal 'No licenses left', license_alert_message
  end

  def test_should_be_paid_tenant_when_current_license_is_paid_and_is_saas_environment
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do

      register_license(:paid => true)

      assert paid_tenant?
    end
  end

  def test_should_not_be_paid_tenant_when_current_license_is_not_paid_and_is_saas_environment
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true', :saas_env => 'test') do

      register_license(:paid => false)

      assert_false paid_tenant?
    end
  end

  def test_should_not_be_paid_tenant_when_current_license_is_paid_and_is_not_saas_environment
    MingleConfiguration.overridden_to(:multitenancy_mode => nil, :saas_env => nil) do

      register_license(:paid => true)

      assert_false paid_tenant?
    end
  end
end
