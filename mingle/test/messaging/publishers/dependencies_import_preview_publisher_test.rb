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

class DependenciesImportPreviewPublisherTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def test_publish_dependencies_import_preview_message
    login_as_admin
    @project1 = create_project(:name => 'project 1', :identifier => 'project_1')
    user = User.first_admin

    export_file = create_dependencies_exporter!([@project1], user).process!
    publisher = DependenciesImportPreviewPublisher.new(user, uploaded_file(export_file))
    publisher.publish_message
    asynch_request = publisher.asynch_request

    messages = all_messages_from_queue(DependenciesImportPreviewProcessor::QUEUE)

    assert_equal 1, messages.size
    assert_equal user.id, messages.first[:user_id]
    assert_equal asynch_request.id, messages.first[:request_id]
  end
end
