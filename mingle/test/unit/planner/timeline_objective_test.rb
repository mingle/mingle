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

class TimelineObjectiveTest < ActiveSupport::TestCase
  def test_work_count_should_default_to_zero
    assert_equal 0, TimelineObjective.new(nil).total_work
    assert_equal 0, TimelineObjective.new(nil).work_done
  end
  
  def test_work_count_should_always_convert_to_int
    objective = TimelineObjective.new(nil)
    objective.total_work = nil
    objective.work_done = nil
    assert_equal 0, objective.total_work
    assert_equal 0, objective.work_done
  end

  def test_should_be_able_to_initialize_from_plan_and_objective_data
    program = program('simple_program')
    plan = program.plan
    objective = program.objectives.first
    project = sp_first_project

    project.with_active_project do
      plan.assign_cards(project, [1], objective)
    end

    timeline_objective = TimelineObjective.from(program.objectives.first, plan)

    assert_equal 1, timeline_objective.total_work
  end
end
