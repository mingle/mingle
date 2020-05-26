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

class SyncObjectiveWorkProcessor < Messaging::DeduplicatingProcessor

  QUEUE = 'mingle.objective.sync'
  route :from => MingleEventPublisher::CARD_VERSION_QUEUE, :to => QUEUE

  def self.enqueue(project_id)
    self.new.send_message(QUEUE, [Messaging::SendingMessage.new(:project_id => project_id)])
  end

  def do_process_message(message)
    Project.with_active_project(message[:project_id]) do |project|
      ObjectiveFilter.for_project(project).sync
    end
  end

  def identity_hash(message)
    {:project_id => message[:project_id].to_s}
  end
end
