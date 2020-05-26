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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../messaging_test_helper')

class ProjectExportPublisherTest < ActiveSupport::TestCase
  include MessagingTestHelper
  
  def test_publish_project_export_message
    project = first_project
    user = User.first_admin
    publisher = ProjectExportPublisher.new(project, user)
    publisher.publish_message
    asynch_request = publisher.asynch_request
    
    messages = all_messages_from_queue(ProjectExportProcessor::QUEUE)

    assert_equal 1, messages.size
    assert_equal project.id, messages[0][:project_id]
    assert_equal user.id, messages[0][:user_id]
    assert_equal asynch_request.id, messages[0][:request_id]
    assert_equal false, messages[0][:template]
  end

  def test_publish_template_export_message
    project = first_project
    user = User.first_admin
    publisher = ProjectExportPublisher.new(project, user, true)
    publisher.publish_message
    asynch_request = publisher.asynch_request
    
    messages = all_messages_from_queue(ProjectExportProcessor::QUEUE)

    assert_equal 1, messages.size
    assert_equal project.id, messages[0][:project_id]
    assert_equal user.id, messages[0][:user_id]
    assert_equal asynch_request.id, messages[0][:request_id]
    assert_equal true, messages[0][:template]
  end
end
