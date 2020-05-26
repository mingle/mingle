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
require File.expand_path(File.dirname(__FILE__) + '/../../test_helpers/planner_forecast_helper')

class SyncObjectiveWorkProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper, PlannerForecastHelper

  def test_sync_work_related_to_objective_and_project
    program = program('simple_program')
    plan = program.plan
    objective_a = program.objectives.find_by_name('objective a')
    project = sp_first_project
    plan.assign_cards(project, [2], objective_a)
    objective_a.filters.create!(:project => project, :params => {:filters => ["[number][is][1]"]})

    SyncObjectiveWorkProcessor.run_once

    assert_equal 1, objective_a.works.size
    assert_equal 1, objective_a.works.first.card_number
  end

  def test_process_message
    processor = SyncObjectiveWorkProcessor.new
    processor.on_message(Messaging::SendingMessage.new({:project_id => 1}))
    processor.on_message(Messaging::SendingMessage.new({:project_id => 2}))
    processor.on_message(Messaging::SendingMessage.new({:project_id => 2}))
    processor.on_message(Messaging::SendingMessage.new({:project_id => 1}))
    assert_equal [1, 2], processor.processed_ids.map{|h| h[:project_id]}.sort
  end
end
