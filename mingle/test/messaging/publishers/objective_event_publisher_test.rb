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

class ObjectiveEventPublishTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan

    route(:from => MingleEventPublisher::OBJECTIVE_VERSION_QUEUE, :to => TEST_QUEUE)
  end

  def test_should_publish_event_onto_queue_on_objective_creation
    objective  = @program.objectives.planned.create(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_message_in_queue objective.versions.first.event.message
  end

end
