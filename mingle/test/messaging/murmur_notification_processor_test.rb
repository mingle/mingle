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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

# Tags: messaging
class MurmurNotificationProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    @old_mingle_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_url = 'http://test.host'
    SmtpConfiguration.load
    ActionMailer::Base.deliveries = []

    login_as_member
    @project_member = User.find_by_login('member')
    @bob = User.find_by_login('bob')
    @first = User.find_by_login('first')
    @project = create_project(:prefix => 'murmur', :users => [@project_member, @bob, @first])
    @project.activate
  end

  def teardown
    MingleConfiguration.site_url = @old_mingle_site_url
  end

  def test_send_notification_email_for_the_team_member_mentioned_in_murmur
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_should_not_send_notification_email_for_deactivated_team_member
    @bob.update_attribute(:activated, false)
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_send_notification_email_for_the_team_member_mentioned_in_murmur_ending_with_comma
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login}, likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_should_not_send_notification_email_for_non_team_member
    @admin = User.find_by_login('admin')
    murmur = @project.murmurs.create!(:murmur => "@#{@admin.login} likes murmur",
                                      :author => User.current)
    assert_equal 0, ActionMailer::Base.deliveries.size
    MurmurNotificationProcessor.run_once
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_should_not_send_multiple_notifications_to_same_user
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} @#{@bob.login} likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_should_not_send_notification_to_murmur_author_if_the_author_was_ated_in_murmur
    murmur = @project.murmurs.create!(:murmur => "@#{User.current.login} likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_should_not_send_notification_if_mentioned_user_has_no_email
    @bob.update_attribute(:email, nil)
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_email_as_login
    @bob.update_attribute(:login, 'bob@foo.com')
    murmur = @project.murmurs.create!(:murmur => "someone @#{@bob.login} likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_send_notification_to_all_users_mentioned_in_murmur
    murmur = @project.murmurs.create!(:murmur => "@#{@first.login} @#{@bob.login} likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_equal ["bob@email.com", "first@email.com"], ActionMailer::Base.deliveries.map(&:bcc).flatten.sort
  end

  def test_send_notification_to_team
    murmur = @project.murmurs.create!(:murmur => "@team likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_equal ["bob@email.com", "first@email.com"], ActionMailer::Base.deliveries.map(&:bcc).flatten.sort
  end

  def test_send_notification_to_group
    group = @project.groups.create!(:name => 'DEVs')
    group.add_member(@bob)
    group.add_member(@first)

    murmur = @project.murmurs.create!(:murmur => "@devs likes murmur",
                                      :author => User.current)
    MurmurNotificationProcessor.run_once
    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_equal ["bob@email.com", "first@email.com"], ActionMailer::Base.deliveries.map(&:bcc).flatten.sort
  end

  def test_should_not_send_notification_on_sns_when_slack_integration_disabled
    @project.murmurs.create!(:murmur => "@team likes murmur",
                                      :author => User.current)

    MurmurNotificationProcessor.run_once

    MurmurSnsNotification.any_instance.expects(:deliver_notify).never
  end

  def test_should_not_send_notification_on_sns_when_slack_not_integrated
    MingleConfiguration.overridden_to(saas_env:  'test') do
      @project.murmurs.create!(:murmur => "@team likes murmur",
                                        :author => User.current)

      SlackApplicationClient.any_instance.expects(:integration_status).with(MingleConfiguration.app_namespace, IntegrationsHelper::APP_INTEGRATION_SCOPE).returns({status: 'NOT_INTEGRATED'})
      MurmurSnsNotification.any_instance.expects(:deliver_notify).never

      MurmurNotificationProcessor.run_once
    end
  end

  def test_should_not_send_notification_on_sns_when_slack_revoke_in_progress
    MingleConfiguration.overridden_to(saas_env:  'test') do
      @project.murmurs.create!(:murmur => "@team likes murmur",
                                        :author => User.current)

      SlackApplicationClient.any_instance.expects(:integration_status).with(MingleConfiguration.app_namespace, IntegrationsHelper::APP_INTEGRATION_SCOPE).returns(status: 'REVOKE_IN_PROGRESS')
      MurmurSnsNotification.any_instance.expects(:deliver_notify).never

      MurmurNotificationProcessor.run_once
    end
  end

  def test_should_send_notification_on_sns_when_slack_integrated
    MingleConfiguration.overridden_to(saas_env:  'test') do
      @project.murmurs.create!(:murmur => "@team likes murmur",
                               :author => User.current)

      SlackApplicationClient.any_instance.expects(:integration_status).with(MingleConfiguration.app_namespace, IntegrationsHelper::APP_INTEGRATION_SCOPE).returns(status: 'INTEGRATED')
      MurmurSnsNotification.any_instance.expects(:deliver_notify).once

      MurmurNotificationProcessor.run_once
    end
  end
end
