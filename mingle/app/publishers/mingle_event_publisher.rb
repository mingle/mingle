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

class MingleEventPublisher < ActiveRecord::Observer
  PAGE_VERSION_QUEUE = 'mingle.events.page_versions'
  CARD_VERSION_QUEUE = 'mingle.events.card_versions'
  DEPENDENCY_VERSION_QUEUE = 'mingle.events.dependency_versions'
  REVISION_QUEUE = 'mingle.events.revisions'
  OBJECTIVE_VERSION_QUEUE = 'mingle.events.objective_versions'
  CARD_COPY_QUEUE = 'mingle.events.card_copy'

  observe Event

  extend Messaging::Base

  def self.publish_for_event(event)
    return if event.kind_of?(CorrectionEvent)

    queue = case event
      when RevisionEvent
        REVISION_QUEUE
      when CardVersionEvent
        CARD_VERSION_QUEUE
      when PageVersionEvent
        PAGE_VERSION_QUEUE
      when ObjectiveVersionEvent
        OBJECTIVE_VERSION_QUEUE
      when DependencyVersionEvent
        DEPENDENCY_VERSION_QUEUE
      when CardCopyEvent::To, CardCopyEvent::From
        CARD_COPY_QUEUE
      when LiveOnlyEvents::Base
         MingleConfiguration.live_wall? ? LiveEventsNotificationProcessor::QUEUE : nil
      else
        Kernel.logger.error {"RuntimeError: No message queue found for event: #{event.inspect}"}
        return nil
    end

    send_message(queue, [event.message]) if queue

  end

  def after_create(event)
    self.class.publish_for_event(event)
  end

end

MingleEventPublisher.instance
