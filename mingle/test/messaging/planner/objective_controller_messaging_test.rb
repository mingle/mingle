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

class ObjectiveControllerMessagingTest < ActionController::TestCase
  include MessagingTestHelper

  def setup
    @controller = create_controller ObjectivesController, :own_rescue_action => false
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)

    login_as_admin

    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_pop_details_should_rebuild_object_snapshots_when_snapshots_missing
    objective_a = @program.objectives.planned.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)
    with_sp_first_project do |project|
      @plan.assign_card_to_objectives(project, project.cards.first, [objective_a])
    end

    clear_message_queue

    get :popup_details, :program_id => @program.to_param, :id => objective_a.to_param

    messages = all_messages_from_queue
    assert_equal 1, messages.count
  end

end
