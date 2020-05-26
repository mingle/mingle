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

class DependenciesImportPublisher
  include Messaging::Base
  attr_reader :asynch_request

  def initialize(user, import_preview_asynch_id)
    @import_preview_asynch_request_id = import_preview_asynch_id
    @asynch_request = user.asynch_requests.create_dependencies_import_asynch_request(Time.now.strftime("%Y-%m-%d"))
    @message = message(user)
  end

  def publish_message
    send_message(DependenciesImportProcessor::QUEUE, [@message])
    @message.dup
  end

  def valid_message?
    @asynch_request.valid?
  end

  def validation_errors
    @asynch_request.errors.full_messages.join(",")
  end

  private
  def message(user)
    message_params = {
        :user_id => user.id,
        :request_id => @asynch_request.id,
        :import_preview_asynch_request_id => @import_preview_asynch_request_id
    }
    sending_message = Messaging::SendingMessage.new(message_params)
    @asynch_request.update_attributes(:message => message_params)
    sending_message
  end
end
