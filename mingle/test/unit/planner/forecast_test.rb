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
require File.expand_path(File.dirname(__FILE__) + '/../../test_helpers/planner_forecast_helper')

class ObjectiveSnapshot  
  def stats
    puts %Q{
      total:     #{total}
      completed: #{completed}
      date:      #{dated.strftime("%Y-%m-%d")}
    }
  end
end

class ForecastTest < ActiveSupport::TestCase
  include PlannerForecastHelper

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
    @objective = @program.objectives.find_by_name('objective a')
    @project = sp_second_project
    @plan.program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'closed')
  end

  def test_forecast
    fake_now(2011, 2, 20)
    assign_card(1, @objective)

    fake_now(2011, 2, 21)
    assign_card(2, @objective)

    fake_now(2011, 2, 22)
    assign_card(3, @objective)
    close_card(1)

    fake_now(2011, 2, 24)
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert_equal "03-02-2011", not_likely_forecast_date(@objective, @project)
  end

  def test_forecast_when_remove_work
    fake_now(2011, 2, 20)
    assign_card(1, @objective)

    fake_now(2011, 2, 21)
    assign_card(2, @objective)

    fake_now(2011, 2, 22)
    close_card(1)

    fake_now(2011, 2, 23)

    fake_now(2011, 2, 24)
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    Work.find_by_card_number(2).destroy

    assert_equal "02-24-2011", not_likely_forecast_date(@objective, @project)
  end

  def test_should_be_not_able_to_create_dup_snapshot_for_the_date
    for_postgresql do
      fake_now(2011, 2, 20)
      assign_project_cards(@objective, @project)

      create_snapshot(1, 0)
      assert_raise ActiveRecord::StatementInvalid do
        create_snapshot(2, 1)
      end
    end
  end

  def test_objective_forecast_with_no_snapshots
    fake_now(2011, 2, 20)
    assert not_likely_forecast(@objective, @project).no_velocity?
  end

  def test_objective_forecast_for_objectives_with_zero_velocity
    fake_now(2012, 1, 1)
    assign_card(1, @objective)

    fake_now(2012, 1, 2)
    assign_card(2, @objective)

    fake_now(2012, 1, 3)
    assign_card(3, @objective)

    fake_now(2012, 1, 4)
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert not_likely_forecast(@objective, @project).no_velocity?
  end

  def test_objective_completed_today_forecast
    fake_now(2012, 1, 1)
    objective = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 3.days.from_now(Clock.now) })
    assign_card(1, objective)
    assign_card(2, objective)

    fake_now(2012, 1, 2)
    close_card(1)
    close_card(2)

    ObjectiveSnapshot.rebuild_snapshots_for(objective.id, @project.id)
    assert_equal "01-02-2012", not_likely_forecast(objective, @project).date.strftime("%m-%d-%Y")
  end

  def test_should_be_late_when_forecast_date_is_after_objective_end_date
    @objective.update_attribute :start_at, Date.new(2012, 1, 1)

    fake_now(2012, 1, 1)
    assign_card(1, @objective)

    fake_now(2012, 1, 2)
    assign_card(2, @objective)

    fake_now(2012, 1, 3)
    assign_card(3, @objective)
    close_card(1)

    @objective.end_at = Clock.now

    fake_now(2012, 1, 3, 10)

    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert_equal "01-07-2012", not_likely_forecast(@objective, @project).date.strftime("%m-%d-%Y")
    assert not_likely_forecast(@objective, @project).late?

    @objective.end_at = Clock.now + 4.days
    assert !not_likely_forecast(@objective, @project).late?
  end

  def test_should_not_be_late_when_all_work_completed
    fake_now(2012, 1, 1)
    @objective.end_at = Clock.now + 1.day
    assign_card(1, @objective)
    assign_card(2, @objective)
    assign_card(3, @objective)
    
    fake_now(2012, 1, 2)
    
    fake_now(2012, 1, 3)    
    close_card(1)

    fake_now(2012, 1, 4)
    
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    
    assert not_likely_forecast(@objective, @project).late?
    
    close_card(2)
    close_card(3)

    assert !not_likely_forecast(@objective, @project).late?
  end

  def test_should_not_be_late_if_no_velocity
    fake_now(2012, 1, 1)
    assign_card(1, @objective)

    fake_now(2012, 1, 2)
    assign_card(2, @objective)

    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    @objective.end_at = Clock.now

    assert !not_likely_forecast(@objective, @project).late?
  end

  def test_to_json
    fake_now(2012, 1, 1)

    assert_match /\"no_velocity\":true/, forecast_json

    assign_project_cards(@objective, @project)

    close_card(1)
    fake_now(2012, 1, 2, 1)
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert_match /\"no_velocity\":false/, forecast_json
  end

  def forecast_json
    Plan::Forecast.new(@objective).for(@project).to_json
  end

  def test_forecast_date_should_be_same_as_last_date_of_all_work_done

    fake_now(2012, 1, 1)
    assign_card(1, @objective)
    @objective.start_at = Clock.now
    @objective.end_at = Clock.now + 10
    @objective.save!

    fake_now(2012, 1, 2)
    assign_card(2, @objective)

    fake_now(2012, 1, 3)
    assign_card(3, @objective)
    close_card(1)

    fake_now(2012, 1, 4)
    close_card(2)
    close_card(3)

    fake_now(2012, 1, 6)
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert_equal "01-04-2012", not_likely_forecast(@objective, @project).date.strftime("%m-%d-%Y")
  end

  private

  def create_snapshot(total, completed)
    ObjectiveSnapshot.create!(:objective => @objective, :project => @project, :dated => Clock.today, :total => total, :completed => completed)
  end
end
