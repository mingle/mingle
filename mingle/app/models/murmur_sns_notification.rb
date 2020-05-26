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

class MurmurSnsNotification

  NOTIFICATION_SUBJECT = 'MurmurNotification'

  def deliver_notify(users, project, murmur)
    return unless project_mapped?(project)

    message = create_message(murmur, project, users)
    sns.publish message
  end

  private

  def sns
    AWS::SNS::Client.new(credentials: Aws::Credentials.new, region: MingleConfiguration.slack_app_aws_region)
  end

  def users_with_subscription(users, project, murmur)
    users = users.select {|user| murmur.mentions.include? user.login }
    users.inject({}) do |subscribed_users, user|
      subscribed_users[user.login] = {
          userId: user.id,
          subscribed: user.display_preference.read_project_preference(project, :slack_murmur_subscription)
      }
      subscribed_users
    end
  end

  def project_mapped?(project)
    mapped_projects = SlackApplicationClient.new(Aws::Credentials.new).mapped_projects[:mappings]
    mapped_projects.find { |project_mapping| project_mapping[:mingleTeamId] == project.team.id }
  end

  def create_message(murmur, project, users)
    card_number = murmur.respond_to?(:origin) ? murmur.origin.number : 0
    message = {
        tenantName: MingleConfiguration.app_namespace,
        projectId: project.identifier,
        mingleTeamId: project.team.id,
        projectName: project.name,
        murmur: murmur.murmur,
        mentionedUsers: users_with_subscription(users, project, murmur),
        cardNumber: card_number,
        cardKeyWords: project.card_keywords.to_s,
        author: murmur.author.name,
        authorId: murmur.author.id
    }.to_json
    Rails.logger.info("MurmurSnsNotification: message: #{message}, notification_topic_arn: #{notification_topic_arn}")
    {topic_arn: notification_topic_arn, message: message, subject: NOTIFICATION_SUBJECT}
  end

  def notification_topic_arn
    return @topic_arn  if @topic_arn

    topic_arns = sns.list_topics.topics
    topic_arn_hash = topic_arns.find { |topic_arn_hash| topic_arn_hash[:topic_arn] =~ /#{MingleConfiguration.app_environment}-#{MingleConfiguration.slack_sns_notification_topic}$/ }
    @topic_arn = topic_arn_hash && topic_arn_hash[:topic_arn]
  end

end
