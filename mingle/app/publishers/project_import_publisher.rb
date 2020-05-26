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

class ProjectImportPublisher
  include Messaging::Base, DeliverableImportExport::ImportFileSupport

  def initialize(user, project_name, project_identifier)
    @user = user
    @project_name = project_name
    @project_identifier = project_identifier
  end

  def publish_message(origin_zip_file)
    @user.asynch_requests.create_project_import_asynch_request(@project_identifier, origin_zip_file).tap do |asynch_request|
      msg = message(asynch_request)
      asynch_request.update_attributes(:message => msg)
      send_message(queue_name, [Messaging::SendingMessage.new(msg)])
    end
  end

  def publish_s3_message(s3_object_name)
    if MingleConfiguration.app_namespace && s3_object_name !~ /\A#{MingleConfiguration.app_namespace}\//
      raise "S3 object name #{s3_object_name} should start with #{MingleConfiguration.app_namespace}"
    end
    @user.asynch_requests.create_project_import_asynch_request(@project_identifier, nil).tap do |asynch_request|
      msg = message(asynch_request).merge(:s3_object_name => s3_object_name)
      asynch_request.update_attributes(:message => msg)
      send_message(queue_name, [Messaging::SendingMessage.new(msg)])
    end
  end

  private
  def queue_name()
    ProjectImportProcessor::QUEUE
  end

  def message(asynch_request)
    {
      :user_id => @user.id,
      :request_id => asynch_request.id,
      :project_identifier => @project_identifier,
      :project_name => @project_name
    }
  end
end
