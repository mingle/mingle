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

# Tags: messaging
class AsynchRequestPublisherTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def test_should_send_message_to_project_import_queue_when_a_project_import_related_asynch_request_created
    route(:from => ProjectImportProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_member
    @member = User.find_by_login('member')
    with_first_project do |project|
      export_file = create_project_exporter!(project, @member).export
      import = create_project_importer!(@member, export_file, 'new name', 'new_identifier')
      asynch_request = import.progress

      assert_message_in_queue(:project_identifier => "new_identifier",
       :user_id => @member.id,
       :request_id => asynch_request.id,
       :project_name => "new name")
    end
  end

  def test_should_send_message_to_card_import_preview_queue_when_a_card_import_preview_related_asynch_request_created
    route(:from => CardImportPreviewProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_member
    @member = User.find_by_login('member')
    with_first_project do |project|
      import_file = SwapDir::CardImportingPreview.file(project, 'foo')
      card_importing_preivew = create_card_import_preview!(project, import_file.pathname)
      asynch_request = card_importing_preivew.progress

      assert_message_in_queue(:user_id=>@member.id,
                              :project_id=>project.id,
                              :request_id => asynch_request.id)
    end
  end

  def test_should_not_send_message_to_project_import_queue_when_the_asynch_request_is_created_for_other_target
    route(:from => ProjectImportProcessor::QUEUE, :to => TEST_QUEUE)
    login_as_member
    @member = User.find_by_login('member')
    with_first_project do |project|
      project_exporter = create_project_exporter!(project, @member)

      asynch_request = project_exporter.progress

      assert_receive_nil_from_queue
    end
  end
end
