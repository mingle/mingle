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

class LiveEventsNotificationProcessor < Messaging::MessageSortingProcessor
  QUEUE = "mingle.firebase.live_events"
  route :from => MingleEventPublisher::CARD_VERSION_QUEUE, :to => QUEUE

  def on_message(message)

    if MingleConfiguration.firebase_app_url
      project = Project.find_by_id(message[:project_id])
      return unless project

      project.with_active_project do
        Event.lock_and_generate_changes!(message[:id])
        event = Event.find_by_id(message[:id])
        notifier.deliver_notify(project, event) if event
      end
    end

  end

  protected

  def notifier
    @notifier ||= FirebaseLiveEventNotification.new(
      FirebaseClient.new(
        MingleConfiguration.firebase_app_url,
        MingleConfiguration.firebase_secret
      )
    )
  end

end
