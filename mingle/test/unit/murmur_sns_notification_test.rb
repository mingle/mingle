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

class MurmurSnsNotificationTest < ActiveSupport::TestCase
  include SlackClientStubs

  def setup
    @project = first_project.activate
    @user = create_user!(login: 'user_with_slack_subscription')
    @project.add_member(@user, :full_member)
    MingleConfiguration.slack_sns_notification_topic = 'mingle-notification-topic'
    @notification_topic_arn = 'arn:aws:test-mingle-notification-topic'
    MingleConfiguration.slack_app_url = 'https://slackserver.com'

    @mocked_sns_client = AWS::SNS::Client.new(credentials: Aws::Credentials.new, region: 'aws-region')
    AWS::SNS::Client.stubs(new: @mocked_sns_client)
    @tenant_name = 'app_namespace'
    Timecop.freeze
    stub_mapped_projects_request(@tenant_name, {mappings: [{mingleTeamId: @project.team.id}]})
  end

  def test_should_send_notification_to_users
    MingleConfiguration.overridden_to(app_namespace: @tenant_name, app_environment: 'test') do
      with_fake_aws_env_for_slack_client do
        murmur = create_murmur(murmur: "@#{@user.login} please look at the issue", project_id: @project.id, author: @user)

        @mocked_sns_client.expects(:list_topics).returns(OpenStruct.new(topics: [{topic_arn: @notification_topic_arn}]))
        @mocked_sns_client.expects(:publish).with(topic_arn: @notification_topic_arn,
                                                  message: {tenantName: MingleConfiguration.app_namespace,
                                                            projectId: @project.identifier,
                                                            mingleTeamId: @project.team.id,
                                                            projectName: @project.name,
                                                            murmur: murmur.murmur,
                                                            mentionedUsers: {@user.login => {userId: @user.id, subscribed: true}},
                                                            cardNumber: 0,
                                                            cardKeyWords: 'card, #',
                                                            author: murmur.author.name,
                                                            authorId: murmur.author.id}.to_json,
                                                  subject: 'MurmurNotification')

        MurmurSnsNotification.new.deliver_notify([@user], @project, murmur)
      end
    end
  end

  def test_should_not_send_notification_to_users_who_have_not_subscribed_for_slack
    MingleConfiguration.overridden_to(app_namespace: @tenant_name, app_environment: 'test') do
      with_fake_aws_env_for_slack_client do
        user_without_subscription = create_user!(login: 'user_without_slack_subscription')
        @project.add_member(user_without_subscription, :full_member)
        user_without_subscription.display_preference.update_project_preference(@project, :slack_murmur_subscription, false)

        murmur = create_murmur(murmur: "@#{@user.login} @#{user_without_subscription.login} please look at the issue",
                               project_id: @project.id, author: @user)

        @mocked_sns_client.expects(:list_topics).returns(OpenStruct.new(topics: [{topic_arn: @notification_topic_arn}]))
        @mocked_sns_client.expects(:publish).with(topic_arn: @notification_topic_arn,
                                                  message: {tenantName: MingleConfiguration.app_namespace,
                                                            projectId: @project.identifier,
                                                            mingleTeamId: @project.team.id,
                                                            projectName: @project.name,
                                                            murmur: murmur.murmur,
                                                            mentionedUsers: {
                                                                @user.login => {userId: @user.id, subscribed: true},
                                                                user_without_subscription.login => {userId: user_without_subscription.id, subscribed: false}
                                                            },
                                                            cardNumber: 0,
                                                            cardKeyWords: 'card, #',
                                                            author: murmur.author.name,
                                                            authorId: murmur.author.id}.to_json,
                                                  subject: 'MurmurNotification')

        MurmurSnsNotification.new.deliver_notify([@user, user_without_subscription], @project, murmur)
      end
    end
  end

  def test_should_not_send_notification_for_projects_not_mapped_to_slack
    MingleConfiguration.overridden_to(app_namespace: @tenant_name, app_environment: 'test') do
      with_fake_aws_env_for_slack_client do
        stub_mapped_projects_request(@tenant_name, {mappings: [], ok: false, error: 'tenant_does_not_exist'})

        murmur = create_murmur(murmur: "@#{@user.login} please look at the issue",
                               project_id: @project.id, author: @user)

        @mocked_sns_client.expects(:list_topics).never
        @mocked_sns_client.expects(:publish).never

        MurmurSnsNotification.new.deliver_notify([@user], @project, murmur)
      end
    end
  end

  def test_should_send_card_number_for_card_comments
    MingleConfiguration.overridden_to(app_namespace: @tenant_name, app_environment: 'test') do
      with_fake_aws_env_for_slack_client do
        murmur = card.origined_murmurs.create!(murmur: "@#{@user.login} look at this", author: @user, project_id: @project.id)

        @mocked_sns_client.expects(:list_topics).returns(OpenStruct.new(topics: [{topic_arn: @notification_topic_arn}]))
        @mocked_sns_client.expects(:publish).with(topic_arn: @notification_topic_arn,
                                                  message: {tenantName: MingleConfiguration.app_namespace,
                                                            projectId: @project.identifier,
                                                            mingleTeamId: @project.team.id,
                                                            projectName: @project.name,
                                                            murmur: murmur.murmur,
                                                            mentionedUsers: {@user.login => {userId: @user.id, subscribed: true}},
                                                            cardNumber: card.number,
                                                            cardKeyWords: 'card, #',
                                                            author: murmur.author.name,
                                                            authorId: murmur.author.id}.to_json,
                                                  subject: 'MurmurNotification')

        MurmurSnsNotification.new.deliver_notify([@user], @project, murmur)
      end
    end
  end

  def test_should_not_add_mentioned_users_for_team_mentions
    MingleConfiguration.overridden_to(app_namespace: @tenant_name, app_environment: 'test') do
      with_fake_aws_env_for_slack_client do
        murmur = create_murmur(murmur: '@team please look at the issue',
                               project_id: @project.id, author: @user)

        @mocked_sns_client.expects(:list_topics).returns(OpenStruct.new(topics: [{topic_arn: @notification_topic_arn}]))
        @mocked_sns_client.expects(:publish).with(topic_arn: @notification_topic_arn,
                                                  message: {tenantName: MingleConfiguration.app_namespace,
                                                            projectId: @project.identifier,
                                                            mingleTeamId: @project.team.id,
                                                            projectName: @project.name,
                                                            murmur: murmur.murmur,
                                                            mentionedUsers: {},
                                                            cardNumber: 0,
                                                            cardKeyWords: 'card, #',
                                                            author: murmur.author.name,
                                                            authorId: murmur.author.id}.to_json,
                                                  subject: 'MurmurNotification')

        MurmurSnsNotification.new.deliver_notify([@user], @project, murmur)
      end
    end
  end

  def test_should_send_murmur_author_and_id_in_notification_sent_to_slack
    MingleConfiguration.overridden_to(app_namespace: @tenant_name, app_environment: 'test') do
      with_fake_aws_env_for_slack_client do
        murmur = create_murmur(murmur: '@team please look at the issue',
                               project_id: @project.id, author: @user)

        @mocked_sns_client.expects(:list_topics).returns(OpenStruct.new(topics: [{topic_arn: @notification_topic_arn}]))
        @mocked_sns_client.expects(:publish).with(topic_arn: @notification_topic_arn,
                                                  message: {tenantName: MingleConfiguration.app_namespace,
                                                            projectId: @project.identifier,
                                                            mingleTeamId: @project.team.id,
                                                            projectName: @project.name,
                                                            murmur: murmur.murmur,
                                                            mentionedUsers: {},
                                                            cardNumber: 0,
                                                            cardKeyWords: 'card, #',
                                                            author: murmur.author.name,
                                                            authorId: murmur.author.id}.to_json,
                                                  subject: 'MurmurNotification')

        MurmurSnsNotification.new.deliver_notify([@user], @project, murmur)
      end
    end

  end

  def teardown
    Timecop.return
  end

  private
  def card
    @card ||= @project.cards.first
  end
end
