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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class PlanTest < ActiveSupport::TestCase
  def setup
    create(:admin, login: :admin)
    login_as_admin
    @program = create(:program)
  end

  context 'PlanValidations' do
    subject { FactoryGirl.build(:plan) }
    should belong_to(:program)
    should validate_presence_of(:program)
    should validate_presence_of(:start_at)
    should validate_presence_of(:end_at)
  end

  def test_end_date_should_be_after_start_date
    plan = @program.plan
    plan.end_at, plan.start_at = plan.start_at, plan.end_at
    assert plan.invalid?
    assert_equal ['should be after start date'], plan.errors[:end_at]
  end

  def test_should_plan_backlog_objective_retaining_value_statement_value_size
    Timecop.freeze(2012, 10, 10) do
      backlog_objective = @program.objectives.backlog.create!(name: 'test', value_statement: "s\n  *a\n  *b", value: 10, size: 20)
      @program.plan.plan_backlog_objective(backlog_objective)

      assert_false @program.objectives.backlog.any? { |o| o.name == 'test' }
      objective = @program.objectives.planned.find_by_name('test')
      assert_equal 'test', objective.name
      assert_equal Clock.today.beginning_of_month, objective.start_at
      assert_equal Clock.today.end_of_month, objective.end_at
      assert_equal 6, objective.vertical_position

      assert_equal 10, objective.value
      assert_equal 20, objective.size
      assert_equal "<p>s</p></br><p>&nbsp;&nbsp;*a</p></br><p>&nbsp;&nbsp;*b</p>", objective.value_statement
    end
  end

  def test_should_place_backlog_objectives_in_the_next_alternating_available_row_on_plan
    backlog_objective = @program.objectives.backlog.create!(name: "first objective")
    @program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 6, @program.objectives.planned.find_by_name("first objective").vertical_position

    backlog_objective = @program.objectives.backlog.create!(name: "second objective")
    @program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 5, @program.objectives.planned.find_by_name("second objective").vertical_position

    backlog_objective = @program.objectives.backlog.create!(name: "third objective")
    @program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 7, @program.objectives.planned.find_by_name("third objective").vertical_position
  end

  def test_should_stack_objectives_in_the_middle_if_all_vertical_positions_are_taken

    13.times do |i|
      backlog_objective = @program.objectives.backlog.create!(:name => "objective #{i}")
      @program.plan.plan_backlog_objective(backlog_objective)
    end

    backlog_objective = @program.objectives.backlog.create!(:name => "thirteenth objective")
    @program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 13, @program.objectives.planned.find_by_name("thirteenth objective").vertical_position

    backlog_objective = @program.objectives.backlog.create!(:name => "another one")
    @program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 6, @program.objectives.planned.find_by_name("another one").vertical_position
  end

  def test_should_position_new_objectives_on_row_when_existing_objectives_start_and_end_outside_current_month
    Timecop.freeze(2012, 10, 30) do
      backlog_objective = @program.objectives.backlog.create!(:name => 'first objective')

      @program.plan.plan_backlog_objective(backlog_objective)
      objective = @program.objectives.planned.find_by_name("first objective")
      objective.update_attributes!({:start_at => Clock.now.advance(:months => 1), :end_at => Clock.now.advance(:months => 2)})
      assert_equal 6, objective.vertical_position

      backlog_objective = @program.objectives.backlog.create!(:name => "second objective")
      @program.plan.plan_backlog_objective(backlog_objective)
      assert_equal 6, @program.objectives.planned.find_by_name("second objective").vertical_position
    end
  end

  def test_should_find_whether_any_existing_objectives_exist_in_the_current_month_when_multiple_objectives_exist_on_the_same_row
    Timecop.freeze(2012, 10, 10) do
      @program.objectives.planned.create!({:name => 'ends in current month', :start_at => Clock.now.advance(:months => -1), :end_at => Clock.now, :vertical_position => 6})
      @program.objectives.planned.create!({:name => 'objective not in current month', :start_at => Clock.now.advance(:months => 2), :end_at => Clock.now.advance(:months => 3), :vertical_position => 6})

      backlog_objective = @program.objectives.backlog.create!(:name => "new objective")
      @program.plan.plan_backlog_objective(backlog_objective)
      assert_equal 5, @program.objectives.planned.find_by_name("new objective").vertical_position
    end
  end

  def test_should_not_populate_spot_when_surrounded_with_an_existing_objective
    Timecop.freeze(2012, 10, 10) do
      @program.objectives.planned.create!({:name => 'surrounds current month', :start_at => Clock.now.advance(:months => -1), :end_at => Clock.now.advance(:months => 2), :vertical_position => 6})
      assert_equal 6, @program.objectives.planned.find_by_name('surrounds current month').vertical_position

      backlog_objective = @program.objectives.backlog.create!(:name => "second objective")
      @program.plan.plan_backlog_objective(backlog_objective)
      assert_equal 5, @program.objectives.planned.find_by_name("second objective").vertical_position
    end
  end

  def test_should_place_newest_objective_two_weeks_apart_in_the_middle_of_timeline_when_timeline_is_full
    Timecop.freeze(2012, 10, 10) do
      14.times do |i|
        backlog_objective = @program.objectives.backlog.create!(:name => "objective #{i}")
        @program.plan.plan_backlog_objective(backlog_objective)
      end
      existing_objective = @program.objectives.planned.find_by_vertical_position(6)

      backlog_objective = @program.objectives.backlog.create!(:name => "first objective")
      @program.plan.plan_backlog_objective(backlog_objective)
      backlog_objective = @program.objectives.backlog.create!(:name => "second objective")
      @program.plan.plan_backlog_objective(backlog_objective)
      backlog_objective = @program.objectives.backlog.create!(:name => "third objective")
      @program.plan.plan_backlog_objective(backlog_objective)
      new_objective = @program.objectives.planned.find_by_name("first objective")
      assert_equal 6, new_objective.vertical_position
      assert_equal Clock.now.beginning_of_month.advance(:weeks => 2).to_date, new_objective.start_at
      assert_equal Clock.now.beginning_of_month.advance(:weeks => 6).to_date, new_objective.end_at

      new_objective = @program.objectives.planned.find_by_name("second objective")
      assert_equal 6, new_objective.vertical_position
      assert_equal Clock.now.beginning_of_month.advance(:weeks => 4).to_date, new_objective.start_at
      assert_equal Clock.now.beginning_of_month.advance(:weeks => 8).to_date, new_objective.end_at

      new_objective = @program.objectives.planned.find_by_name("third objective")
      assert_equal 6, new_objective.vertical_position
      assert_equal Clock.now.beginning_of_month.advance(:weeks => 6).to_date, new_objective.start_at
      assert_equal Clock.now.beginning_of_month.advance(:weeks => 10).to_date, new_objective.end_at
    end
  end

  def test_should_update_planned_objective_position
    backlog_objective_1 = create(:objective, :backlog, name: "backlog_objective_1", program_id: @program.id)
    @program.plan.plan_backlog_objective(backlog_objective_1)

    assert_equal 1, backlog_objective_1.position
    backlog_objective_2 = create(:objective, :backlog, name: "backlog_objective_2", program_id: @program.id)
    @program.plan.plan_backlog_objective(backlog_objective_2)

    assert_equal 2, backlog_objective_1.reload.position
    assert_equal 1, backlog_objective_2.position

  end
end
