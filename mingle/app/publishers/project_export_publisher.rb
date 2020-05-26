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

class ProjectExportPublisher
  include Messaging::Base
  
  attr_reader :asynch_request
  
  def initialize(project, user, template = false)
    @asynch_request = user.asynch_requests.create_project_export_asynch_request(project.identifier)
    @message = message(project, user, template)
  end  

  def publish_message
    send_message(ProjectExportProcessor::QUEUE, [@message])
    @message.dup
  end
  
  private
  
  def message(project, user, template = false)
    message_params = { 
        :project_id => project.id,
        :user_id => user.id,
        :request_id => @asynch_request.id,
        :template => template
    }
    sending_message = Messaging::SendingMessage.new(message_params)
    @asynch_request.update_attributes(:message => message_params)
    sending_message
  end  
  
  
end
