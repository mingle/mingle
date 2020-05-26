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
require File.expand_path(File.dirname(__FILE__) + '/../../../app/publishers/program_export_publisher')
require File.expand_path(File.dirname(__FILE__) + '/../../../app/processors/program_export_processor')

class ProgramExportPublisherTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def test_publish_program_export_message
    login_as_admin
    program = create_program
    program.projects << first_project
    user = User.first_admin

    publisher = ProgramExportPublisher.new(program, user)
    publisher.publish_message
    asynch_request = publisher.asynch_request

    messages = all_messages_from_queue(ProgramExportProcessor::QUEUE)

    assert_equal 1, messages.size
    assert_equal program.identifier, messages.first[:program_identifier]
    assert_equal user.id, messages.first[:user_id]
    assert_equal asynch_request.id, messages.first[:request_id]
  end

end
