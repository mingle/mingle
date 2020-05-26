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

class MurmursPublisherTest < ActiveSupport::TestCase
  include MessagingTestHelper
  def setup
    @project = first_project
    @project.activate
    @member = User.find_by_login('member')
  end

  def test_publish_murmur_event_message
    route(:from => MurmursPublisher::QUEUE, :to => TEST_QUEUE)
    murmur = @project.murmurs.build :packet_id => '12345abc'.uniquify, :jabber_user_name => 'mike', :author => @member, :murmur => 'this is a piece of message', :id => 999
    MurmursPublisher.instance.after_create(murmur)

    messages = all_messages_from_queue(TEST_QUEUE)

    assert_equal 1, messages.size
    assert_equal murmur.project.id, messages[0][:project_id]
    assert_equal murmur.id, messages[0][:id]
  end

end
