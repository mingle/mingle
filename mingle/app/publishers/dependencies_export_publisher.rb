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

class DependenciesExportPublisher
  include Messaging::Base

  attr_reader :asynch_request

  def initialize(projects, user)
    @asynch_request = user.asynch_requests.create_dependencies_export_asynch_request(Time.now.strftime("%Y-%m-%d"))
    @message = message(projects, user)
  end

  def publish_message
    send_message(DependenciesExportProcessor::QUEUE, [@message])
    @message.dup
  end

  private

  def message(projects, user, template = false)
    message_params = {
        :project_identifiers => projects.map(&:identifier).join(","),
        :user_id => user.id,
        :request_id => @asynch_request.id
    }
    sending_message = Messaging::SendingMessage.new(message_params)
    @asynch_request.update_attributes(:message => message_params)
    sending_message
  end
end
