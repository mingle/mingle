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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../messaging_test_helper')

class LicenseAlertPublisherTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def test_should_enqueue_message_for_5_licenses_left_for_paid_sites
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true',
                                      :saas_env => 'test') do
      company_name = 'ThoughtWorks Technologies Pvt. Ltd.'
      register_license(:paid => true,
                       :max_active_users => User.activated_full_users + 6,
                       :company_name => company_name)
      create_user!
      messages = all_messages_from_queue(LicenseAlertProcessor::QUEUE)

      assert_one_message(messages, company_name, '5 licenses left')
    end
  end

  def test_should_not_enqueue_message_for_trial_sites_on_saas_environment
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true',
                                      :saas_env => 'test') do
      register_license(:trial => true, :max_active_users => User.activated_full_users + 1)
      create_user!

      assert_receive_nil_from_queue(LicenseAlertProcessor::QUEUE)
    end
  end

  def test_should_not_enqueue_message_for_installer_version
    MingleConfiguration.overridden_to(:multitenancy_mode => nil,
                                      :saas_env => nil) do
      register_license(:paid => true, :max_active_users => User.activated_full_users + 5)
      create_user!

      assert_receive_nil_from_queue(LicenseAlertProcessor::QUEUE)
    end
  end

  def test_should_enqueue_message_for_no_licenses_left_for_paid_sites
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true',
                                      :saas_env => 'test') do
      register_license(:paid => true, :max_active_users => User.activated_full_users + 1, :company_name => 'ThoughtWorks')
      create_user!
      messages = all_messages_from_queue(LicenseAlertProcessor::QUEUE)

      assert_one_message(messages, 'ThoughtWorks', 'No licenses left')
    end
  end

  def test_should_not_enqueue_message_for_paid_sites_having_more_than_5_licenses_left
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true',
                                      :saas_env => 'test',
                                      :app_namespace => 'tenant_name') do
      register_license(:paid => true, :max_active_users => User.activated_full_users + 7)
      create_user!

      assert_receive_nil_from_queue(LicenseAlertProcessor::QUEUE)
    end
  end

  def test_should_not_enqueue_message_for_paid_sites_when_licenses_left_are_between_5_and_0
    MingleConfiguration.overridden_to(:multitenancy_mode => 'true',
                                      :saas_env => 'test',
                                      :app_namespace => 'tenant_name') do
      register_license(:paid => true, :max_active_users => User.activated_full_users + 4)
      create_user!

      assert_receive_nil_from_queue(LicenseAlertProcessor::QUEUE)
    end
  end

  private

  def assert_one_message(messages, company_name, alert_type)
    assert_equal 1, messages.size
    assert_equal company_name, messages[0][:tenant_organization]
    assert_equal MingleConfiguration.site_url, messages[0][:tenant_url]
    assert_equal alert_type, messages[0][:alert_message]
  end
end
