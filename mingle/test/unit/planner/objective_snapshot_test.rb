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

class ObjectiveSnapshotTest < ActiveSupport::TestCase
  include PlannerForecastHelper
  
  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
    @objective = @program.objectives.find_by_name('objective a')
    @project = sp_first_project
    @plan.program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'closed')
  end

  def teardown
    Clock.reset_fake
  end

  def test_should_refresh_old_snapshots_if_previously_completed_work_is_removed
    fake_now(2011, 2, 21)
    with_sp_first_project do |project|
      close_card(1)
      close_card(2)
      assign_card(1, @objective)
      assign_card(2, @objective)
    end

    fake_now(2011, 2, 22)
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert_equal 2, ObjectiveSnapshot.last.total
    assert_equal 2, ObjectiveSnapshot.last.completed

    @objective.works.last.destroy
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert_equal 1, ObjectiveSnapshot.last.total
    assert_equal 1, ObjectiveSnapshot.last.completed
  end

  def test_should_not_repeat_snapshots
    fake_now(2011, 2, 21)
    assign_card(1, @objective)
    close_card(1)

    fake_now(2011, 2, 22)
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
  
    assert_no_difference "ObjectiveSnapshot.count" do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
  end

  def test_take_snapshot_from_work_versions_table_before_today
    fake_now(2011, 2, 20)
    assign_project_cards(@objective, @project)
    fake_now(2011, 2, 21)
    assert_difference "ObjectiveSnapshot.count", 1 do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
    assert_equal 2, @objective.objective_snapshots.first.total
    assert_equal 0, @objective.objective_snapshots.first.completed

    close_card(1)

    fake_now(2011, 2, 22)
    assert_difference "ObjectiveSnapshot.count", 1 do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
    assert_equal 2, @objective.objective_snapshots.last.total
    assert_equal 1, @objective.objective_snapshots.last.completed
  end

  def test_take_snapshot_from_work_versions_table_day_by_day
    fake_now(2011, 2, 20)
    assign_project_cards(@objective, @project)
    
    fake_now(2011, 2, 22)
    assert_difference "ObjectiveSnapshot.count", 2 do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
    
    fake_now(2011, 2, 25)
    assert_difference "ObjectiveSnapshot.count", 3 do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
  end

  def test_should_not_take_snapshot_before_start_date_of_the_objective
    fake_now(2011, 2, 10)
    assign_project_cards(@objective, @project)
    
    fake_now(2011, 2, 12)
    assert_no_difference "ObjectiveSnapshot.count" do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
    
    fake_now(2011, 2, 15)
    assert_no_difference "ObjectiveSnapshot.count" do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end

    fake_now(2011, 2, 21)
    assert_difference "ObjectiveSnapshot.count", 1 do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
  end

  def test_should_not_take_snapshot_once_snapshot_is_same_with_last_and_completed
    fake_now(2011, 2, 21)
    assign_card(1, @objective)
    close_card(1)

    fake_now(2011, 2, 22)
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    assert_no_difference "ObjectiveSnapshot.count" do
      ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    end
  end
  
  def test_snapshots_till_date_for_project
    fake_now(2011, 2, 21)
    assign_card(1, @objective)
    
    project2 = sp_second_project
    @plan.program.update_project_status_mapping(project2, :status_property_name => 'status', :done_status => 'closed')
    @plan.assign_cards(project2, [1], @objective)
    
    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)
    
    snapshots_till_date = ObjectiveSnapshot.snapshots_till_date(@objective, @project)
    assert_equal 2, snapshots_till_date.size
    assert_equal [@project, @project], snapshots_till_date.map(&:project)
  end
  
  def test_snapshots_till_date_gives_till_last_completed_date
    fake_now(2011, 2, 21)
    assign_card(1, @objective)
    
    fake_now(2011, 2, 22)
    close_card(1)
    
    completed_date = Clock.today
    fake_now(2011, 2, 23)

    ObjectiveSnapshot.rebuild_snapshots_for(@objective.id, @project.id)

    snapshots_till_date = ObjectiveSnapshot.snapshots_till_date(@objective, @project)
    assert_equal 3, snapshots_till_date.size
    last_date = snapshots_till_date.last.dated
    assert_equal completed_date.strftime("%Y-%m-%d"), last_date.strftime("%Y-%m-%d")
  end

  def test_snapshots_till_date_gives_today_when_not_all_completed
    fake_now(2011, 2, 23)

    snapshots_till_date = ObjectiveSnapshot.snapshots_till_date(@objective, @project)
    last_date = snapshots_till_date.last.dated
    assert_equal Clock.today, last_date
  end

  def test_snapshots_till_date_guarantees_order_by_timestamp
    ObjectiveSnapshot.new(:objective => @objective, :project => @project, :total => 0, :completed => 0, :dated => Date.new(2011, 2, 22)).save
    ObjectiveSnapshot.new(:objective => @objective, :project => @project, :total => 0, :completed => 0, :dated => Date.new(2011, 2, 21)).save
    ObjectiveSnapshot.new(:objective => @objective, :project => @project, :total => 0, :completed => 0, :dated => Date.new(2011, 2, 23)).save

    @objective.start_at = Date.new(2011, 2, 20)
    @objective.end_at = Date.new(2011, 2, 24)
    @objective.save!

    fake_now(2011, 2, 24)

    snapshots_till_date = ObjectiveSnapshot.snapshots_till_date(@objective, @project)
    expected_dates = [ "2011-02-21", "2011-02-22", "2011-02-23", "2011-02-24"]
    actual_dates = snapshots_till_date.map { |snap| snap.dated.strftime("%Y-%m-%d") }
    assert_equal expected_dates, actual_dates
  end

  def test_changing_start_date_filters_snapshots_by_start_date_of_objective
    fake_now(2011, 2, 20)
    objective = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 10.days.from_now(Clock.now) })

    assign_card(1, objective)
    close_card(1)
    assign_card(2, objective)

    ObjectiveSnapshot.rebuild_snapshots_for(objective.id, @project.id)

    fake_now(2011, 2, 23)
    close_card(2)

    objective.start_at = Date.new(2011, 2, 22)
    objective.save!

    objectives_till_date = ObjectiveSnapshot.snapshots_till_date(objective, @project)
    assert_equal 1, objectives_till_date.size

    objective.start_at = Date.new(2011, 2, 20)
    objective.save!
    ObjectiveSnapshot.rebuild_snapshots_for(objective.id, @project.id)

    objectives_till_date = ObjectiveSnapshot.snapshots_till_date(objective, @project)
    assert_equal 4, objectives_till_date.size
  end

  def test_progress_shows_all_closed_work_regardless_of_objective_start_date
    fake_now(2011, 2, 20)
    objective = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 10.days.from_now(Clock.now) })

    assign_card(1, objective)
    close_card(1)
    assign_card(2, objective)
    assert_equal 1, objective.progress["sp_first_project"][:done]

    fake_now(2011, 2, 23)
    close_card(2)
    assert_equal 2, objective.progress["sp_first_project"][:done]

    objective.start_at = Date.new(2011, 2, 23)
    objective.save!
    assert_equal 2, objective.progress["sp_first_project"][:done]
  end

  def test_rebuild_snapshots_will_create_empty_snapshots_when_objective_start_date_is_earlier_than_work_start_date
    fake_now(2011, 2, 20)
    objective = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 10.days.from_now(Clock.now) })

    assign_card(1, objective)
    close_card(1)

    assign_card(2, objective)

    fake_now(2011, 2, 23)
    close_card(2)

    objective.start_at = Date.new(2011, 2, 15)
    objective.save!

    ObjectiveSnapshot.rebuild_snapshots_for(objective.id, @project.id)
    snapshots = ObjectiveSnapshot.all
    assert_equal 8, snapshots.count
  end

  def test_rebuild_snapshot_should_use_cards_actual_completed_date_regardless_of_when_it_was_added
    fake_now(2011, 2, 20)
    objective_a = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 10.days.from_now(Clock.now) })

    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      card.update_properties('status' => 'closed')
      card.save!

      fake_now(2011, 2, 21)
      @plan.assign_card_to_objectives(project, card, [objective_a])

      ObjectiveSnapshot.rebuild_snapshots_for(objective_a.id, project.id)
      assert_equal 1, objective_a.objective_snapshots.count
      snapshot = objective_a.objective_snapshots.first
      assert_equal 0, snapshot.total
      assert_equal 1, snapshot.completed
    end
  end

  def test_rebuild_snapshots_should_change_existing_values_when_completed_cards_are_added
    fake_now(2011, 2, 20)
    objective_a = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 10.days.from_now(Clock.now) })
    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      card.update_properties('status' => 'closed')
      card.save!

      @plan.assign_card_to_objectives(project, project.cards.find_by_number(2), [objective_a])

      fake_now(2011, 2, 21)

      ObjectiveSnapshot.rebuild_snapshots_for(objective_a.id, project.id)
      assert_equal 1, objective_a.objective_snapshots.count
      snapshot = objective_a.objective_snapshots.first
      assert_equal 1, snapshot.total
      assert_equal 0, snapshot.completed

      @plan.assign_card_to_objectives(project, card, [objective_a])

      ObjectiveSnapshot.rebuild_snapshots_for(objective_a.id, project.id)

      assert_equal 1, snapshot.reload.completed
    end
  end
  
  def test_snapshot_comparision
    objective_a = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 10.days.from_now(Clock.now) })
    with_sp_first_project do |project|
      snapshot_a = ObjectiveSnapshot.take_from_version(objective_a, project, Clock.now, plan=objective_a.program.plan)
      @plan.assign_card_to_objectives(project, project.cards.find_by_number(2), [objective_a])
      snapshot_b = ObjectiveSnapshot.take_from_version(objective_a, project, Clock.now, plan=objective_a.program.plan)
      assert_false snapshot_b.eql?(snapshot_a)
    end
  end
end
