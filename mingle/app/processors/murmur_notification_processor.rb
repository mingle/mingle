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

class MurmurNotificationProcessor < Messaging::Processor
  QUEUE = 'mingle.murmur.notification'
  route :from => MurmursPublisher::QUEUE, :to => QUEUE

  def on_message(message)
    project = Project.find_by_id(message.property('projectId'))
    murmur = Murmur.find_by_id(message.property('murmurId'))
    return unless project && murmur

    users = project.with_active_project do |proj|
      murmur.mentioned_users
    end

    Rails.logger.info("notify users #{users.map(&:login).inspect}")
    notifications.each do |notification|
      project.with_active_project do
        notification.deliver_notify(users, project, murmur)
      end
    end
  end

  private

  def notifications
    [].tap do |result|
      if MingleConfiguration.firebase_app_url
        client = FirebaseClient.new(MingleConfiguration.firebase_app_url, MingleConfiguration.firebase_secret)
        result << FirebaseUnreadMurmurNotification.new(client)
      end
      if SmtpConfiguration.configured?
        result << MurmurEmailNotification.new
      end
      should_send_sns_notification = send_sns_notification?
      Rails.logger.info("MurmurNotificationProcessor: send_sns_notification? : #{should_send_sns_notification}")
      if should_send_sns_notification
        result << MurmurSnsNotification.new
      end
    end
  end

  def send_sns_notification?
    MingleConfiguration.saas? &&
        SlackApplicationClient.new(Aws::Credentials.new).integration_status(MingleConfiguration.app_namespace, IntegrationsHelper::APP_INTEGRATION_SCOPE)[:status]  == IntegrationsHelper::IntegrationStatus::INTEGRATED
  end

end
