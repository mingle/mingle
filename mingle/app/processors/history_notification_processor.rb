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

class HistoryNotificationProcessor < Messaging::DeduplicatingProcessor
  QUEUE = "mingle.history_notification"
  route :from => MingleEventPublisher::CARD_VERSION_QUEUE,      :to => QUEUE
  route :from => MingleEventPublisher::PAGE_VERSION_QUEUE,      :to => QUEUE
  route :from => MingleEventPublisher::REVISION_QUEUE,          :to => QUEUE

  def initialize
    @smtp_configured = SmtpConfiguration.load
  end

  def do_process_message(message)
    if @smtp_configured
      User.with_first_admin do
        if project = Project.find_by_id(message[:project_id])
          Project.logger.info("Sending of history notifications for #{project.identifier}")
          project.send_history_notifications
        end
      end
    else
      Project.logger.debug("Skipping sending of history notifications because SMTP is not configured.")
    end
  end

  def identity_hash(message)
    {:project_id => message[:project_id].to_s}
  end

end
