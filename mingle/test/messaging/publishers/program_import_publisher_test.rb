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

class ProgramImportPublisherTest < ActiveSupport::TestCase

  def test_asynch_request_and_message_are_created
    user = login_as_admin
    program = create_program

    program.plan.update_attributes(:start_at => 2.days.ago, :end_at => Time.now)
    export_file = create_program_exporter!(program, user).process!

    publisher = ProgramImportPublisher.new(user, uploaded_file(export_file))
    asynch_request = publisher.asynch_request
    message = publisher.publish_message

    assert_equal user.id, message[:user_id]
    assert_equal program.identifier, asynch_request.deliverable_identifier
  end

  def test_import_message_created_properly_for_old_export
    user = login_as_admin
    old_export_file = uploaded_file(export_file('old_plan.plan'))
    asynch_request = ProgramImportPublisher.new(user, old_export_file).asynch_request
    assert_equal 'old_plan', asynch_request.deliverable_identifier
  end

end
