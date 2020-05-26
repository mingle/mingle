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

class PlanTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = create_program
  end

  def test_new_plan_should_default_to_a_month_before_and_11_months_after_today
    Clock.fake_now('2012-10-11')
    program = create_program
    plan = program.plan
    assert_equal Date.new(2012, 9, 10), plan.start_at
    assert_equal Date.new(2013, 9, 15), plan.end_at
  end

  def test_plan_end_date_should_be_required
    plan = @program.plan
    plan.end_at = nil
    assert plan.invalid?
    assert_equal "can't be blank", plan.errors[:end_at]
  end

  def test_plan_start_date_should_be_required
    plan = @program.plan
    plan.start_at = nil
    assert plan.invalid?
    assert_equal "can't be blank", plan.errors[:start_at]
  end

  def test_end_date_should_be_after_start_date
    plan = @program.plan
    plan.end_at, plan.start_at = plan.start_at, plan.end_at
    assert plan.invalid?
    assert_equal "should be after start date", plan.errors[:end_at]
  end

  def test_start_date_should_be_rounded_to_first_monday_prior
    plan = @program.plan
    plan.update_attributes!("start_at" => "2011/3/10", "end_at" => "2012/4/3")
    assert_equal Date.new(2011, 3, 7), plan.start_at

    plan.update_attributes!("start_at" => "2011/3/20", "end_at" => "2012/4/3")
    assert_equal Date.new(2011, 3, 14), plan.start_at

    plan.update_attributes!("start_at" => "2011/3/21", "end_at" => "2012/4/3")
    assert_equal Date.new(2011, 3, 21), plan.start_at
  end

  def test_end_date_should_be_rounded_to_sunday_after
    plan = @program.plan
    plan.update_attributes!("start_at" => "2011/3/1", "end_at" => "2011/3/6")

    assert_equal Date.new(2011, 3, 6), plan.end_at

    plan.update_attributes!("start_at"=>"2011/1/1","end_at" => "2011/3/12")
    assert_equal Date.new(2011, 3, 13), plan.end_at

    plan.update_attributes!("start_at"=>"2011/1/1","end_at" => "2011/3/16")
    assert_equal Date.new(2011, 3, 20), plan.end_at
  end

  def test_should_know_assignable_projects
    all_projects = Project.all_available.size
    assert_equal all_projects, @program.assignable_projects.size
    @program.assign(first_project)
    assert_equal all_projects -1 , @program.reload.assignable_projects.size
  end

  def test_assignable_projects_are_smart_sorted_by_name
    project_90 = Project.create!(:name => '90', :identifier => 'project_90')
    project_9 = Project.create!(:name => '9', :identifier => 'project_9')
    assert @program.assignable_projects.index(project_9) < @program.assignable_projects.index(project_90)
  end

  def test_add_planned_work_should_not_add_duplicate_work_by_card_number
    program = program('simple_program')
    objective = program.objectives.first
    works = []
    with_sp_first_project do |project|
      works << project.cards.first
    end
    program.plan.assign_cards(sp_first_project, works.collect(&:number), objective)
    program.plan.assign_cards(sp_first_project, works.collect(&:number), objective)

    assert_equal(1, objective.works.size)
  end

  def test_should_not_allow_plan_to_start_after_earliest_objective_start_date
    Clock.fake_now(:year => 2011, :month => 01, :day =>01)
    program = program('simple_program')
    plan = program.plan
    earlier_objective = program.objectives.find_by_name('objective a')
    plan.update_attributes("start_at" => program.objectives.last.start_at + 1)
    program.objectives.reverse!
    assert_not plan.valid?
    assert_equal "is later than Feature #{earlier_objective.name.bold} start date of #{earlier_objective.start_at.strftime("%e %b %Y").strip.bold}. Please select an earlier date.", plan.errors[:start_at]
  end

  def test_should_not_allow_plan_to_end_before_latest_objective_end_date
    Clock.fake_now(:year => 2011, :month => 01, :day =>01)
    program = program('simple_program')
    plan = program.plan
    objective = program.objectives.first
    later_objective = program.objectives.last
    plan.update_attributes("end_at" => objective.end_at - 1)
    assert_not plan.valid?
    assert_equal "is earlier than Feature #{later_objective.name.bold} end date of #{later_objective.end_at.strftime("%e %b %Y").strip.bold}. Please select an later date.", plan.errors[:end_at]
  end

  def test_bulk_should_update_updated_at_of_work
    with_new_project do |project|
      create_card!(:name => 'card 1')
      Clock.fake_now(:year => 1977, :month => 12, :day => 16)
      program = create_program
      program.projects << project
      objective_a = create_planned_objective(program, {:name => 'objective a'})
      objective_b = create_planned_objective(program, {:name => 'objective b'})
      program.plan.assign_cards(project, 1, objective_a)
      work_v1 = objective_a.works.first

      Clock.fake_now(:year => 1977, :month => 12, :day => 17)
      program.plan.assign_cards(project, 1, objective_b)
      work_v2 = objective_b.works.first
      assert_not_equal work_v1.updated_at, work_v2.updated_at
    end
  ensure
    Clock.reset_fake
  end

  def test_should_not_change_the_updated_time_when_assign_the_same_card_to_the_same_objective
    with_new_project do |project|
      create_card!(:name => 'card 1')
      Clock.fake_now(:year => 1977, :month => 12, :day => 16)
      program = create_program
      plan = program.plan
      program.projects << project
      objective_a = create_planned_objective(program, {:name => 'objective a'})
      program.plan.assign_cards(project, 1, objective_a)
      original_updated_at = objective_a.works.first.updated_at

      Clock.fake_now(:year => 1977, :month => 12, :day => 17)
      program.plan.assign_cards(project, 1, objective_a)
      assert_equal original_updated_at, objective_a.reload.works.first.updated_at
    end
  ensure
    Clock.reset_fake
  end

  def test_program_destroy_should_leave_nothing_behind
    before_create_plan_count = [Objective, ProgramProject, Work].collect(&:count).sum
    login_as_admin
    with_first_project do |project|
      plan = @program.plan
      @program.projects << project
      objective_a = create_planned_objective(@program, {:name => 'objective a'})
      objective_b = create_planned_objective(@program, {:name => 'objective b'})
      @program.plan.assign_cards(project, create_card!(:name => 'card 1').number, objective_a)
      work = objective_a.works.first
      work.update_attribute(:objective, objective_b)
      @program.destroy
      assert_equal before_create_plan_count, [Objective, ProgramProject, Work].collect(&:count).sum
    end
  end

  def test_program_projects_should_be_uniq
    plan = program('simple_program').plan
    assert_raise ActiveRecord::RecordInvalid do
      plan.program.projects << sp_first_project
    end
  end

  def test_start_at_and_end_at_should_be_date_object
    plan = program('simple_program').plan
    assert_equal Date, plan.start_at.class
    assert_equal Date, plan.end_at.class
  end

  def test_should_generate_work_deletion_version_when_remove_project_from_plan
    program = program('simple_program')
    program.plan.assign_cards(sp_first_project, [1, 2], program.objectives.first)
    program.plan.assign_cards(sp_second_project, [1, 2], program.objectives.first)
    assert_difference "Work.count", -2 do
      assert_difference "ProgramProject.count", -1 do
        program.unassign(sp_first_project)
      end
    end
    assert_equal 2, program.plan.works.created_from(sp_second_project).count
  end

  def test_unassign_project_from_plan_should_not_affect_another_plan_with_that_project
    program = program('simple_program')
    other_program = create_program
    other_program.projects << sp_first_project
    other_programs_objective = create_planned_objective(other_program)
    program.plan.assign_cards(sp_first_project, 1, program.objectives.first)
    other_program.plan.assign_cards(sp_first_project, 1, other_programs_objective)
    assert_no_difference "other_program.plan.works.count" do
      program.unassign(sp_first_project)
    end
  end

  def test_timeline_objectives
    program = program('simple_program')
    objective1 = program.objectives[0]
    objective2 = program.objectives[1]

    program.plan.assign_cards(sp_first_project, [1, 2], objective1)
    program.plan.assign_cards(sp_second_project, [1, 2, 3], objective2)

    work1 = objective1.works.find_by_card_number(1)
    work1.update_attribute(:completed, true)

    expected = {
      :name => objective1.name,
      :id => objective1.id,
      :vertical_position => objective1.vertical_position,
      :start_at => objective1.start_at,
      :end_at => objective1.end_at,
      :url_identifier => objective1.url_identifier,
      :total_work => 2,
      :work_done => 1
    }
    assert expected.to_json, program.plan.timeline_objectives.detect{|s| s.id == expected[:id]}.to_json
  end

  def test_work_completed
    plan = program('simple_program').plan
    objective1 = plan.program.objectives[0]
    project = sp_first_project
    plan.program.update_project_status_mapping(sp_first_project, :status_property_name => nil, :done_status => nil)

    plan.assign_cards(project, [1], objective1)
    plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')

    assert_false plan.works.scheduled_in(objective1).first.completed?
  end

  def test_should_plan_backlog_objective_retaining_value_statement_value_size
    Clock.fake_now(:year => 2012, :month => 10, :day => 10)
    program = create_program
    backlog_objective = program.objectives.backlog.create!(:name => "test", :value_statement => "s\n  *a\n  *b", :value => 10, :size => 20)
    program.plan.plan_backlog_objective(backlog_objective)

    assert_false program.objectives.backlog.any?{|o| o.name == "test" }
    objective = program.objectives.reload.find_by_name("test")
    assert_equal "test", objective.name
    assert_equal Clock.today.beginning_of_month, objective.start_at
    assert_equal Clock.today.end_of_month, objective.end_at
    assert_equal 6, objective.vertical_position

    assert_equal 10, objective.value
    assert_equal 20, objective.size
    assert_equal "s\n  *a\n  *b", objective.value_statement
  ensure
    Clock.reset_fake
  end

  def test_should_place_backlog_objectives_in_the_next_alternating_available_row_on_plan
    program = create_program
    backlog_objective = program.objectives.backlog.create!(:name => "first objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 6, program.objectives.find_by_name("first objective").vertical_position

    backlog_objective = program.objectives.backlog.create!(:name => "second objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 5, program.objectives.find_by_name("second objective").vertical_position

    backlog_objective = program.objectives.backlog.create!(:name => "third objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 7, program.objectives.find_by_name("third objective").vertical_position
  end

  def test_should_stack_objectives_in_the_middle_if_all_vertical_positions_are_taken
    program = create_program

    13.times do |i|
      backlog_objective = program.objectives.backlog.create!(:name => "objective #{i}")
      program.plan.plan_backlog_objective(backlog_objective)
    end

    backlog_objective = program.objectives.backlog.create!(:name => "thirteenth objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 13, program.objectives.find_by_name("thirteenth objective").vertical_position

    backlog_objective = program.objectives.backlog.create!(:name => "another one")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 6, program.objectives.find_by_name("another one").vertical_position
  end

  def test_should_position_new_objectives_on_row_when_existing_objectives_start_and_end_outside_current_month
    Clock.fake_now(:year => 2012, :month => 10, :day => 30)
    program = create_program
    backlog_objective = program.objectives.backlog.create!(:name => 'first objective')

    program.plan.plan_backlog_objective(backlog_objective)
    objective = program.objectives.find_by_name("first objective")
    objective.update_attributes!({:start_at => Clock.now.advance(:months => 1), :end_at => Clock.now.advance(:months => 2)})
    assert_equal 6, objective.vertical_position

    backlog_objective = program.objectives.backlog.create!(:name => "second objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 6, program.objectives.find_by_name("second objective").vertical_position
  ensure
    Clock.reset_fake
  end

  def test_next_available_position_between
    program = create_program
    program.objectives.planned.create!(:name => 'first_objective', :start_at => '2012-11-12',
      :end_at => '2012-12-11', :vertical_position => Plan::Constants::VERTICALLY_MIDDLE_OF_TIMELINE)

    pos = program.plan.next_available_position_between(Date.parse('2012-11-12'), Date.parse('2012-12-11'))
    assert_equal Plan::Constants::VERTICALLY_MIDDLE_OF_TIMELINE - 1, pos
    program.objectives.planned.create!(:name => 'second_objective', :start_at => '2012-11-15',
      :end_at => '2012-12-08', :vertical_position => pos)

    pos = program.plan.next_available_position_between(Date.parse('2012-11-12'), Date.parse('2012-12-11'))
    assert_equal Plan::Constants::VERTICALLY_MIDDLE_OF_TIMELINE + 1, pos
  ensure
    Clock.reset_fake
  end

  def test_should_not_position_new_objectives_on_row_when_existing_objectives_on_row_end_within_current_month
    Clock.fake_now(:year => 2012, :month => 10, :day => 30)
    program = create_program
    program.objectives.planned.create!({:name => 'first objective', :start_at => Clock.now.advance(:months => -1), :end_at => Clock.now.advance(:weeks => -2), :vertical_position => 6})

    backlog_objective = program.objectives.backlog.create!(:name => "second objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 5, program.objectives.find_by_name("second objective").vertical_position
  ensure
    Clock.reset_fake
  end

  def test_should_not_position_new_objectives_on_row_when_existing_objectives_on_row_start_within_current_month
    Clock.fake_now(:year => 2012, :month => 10, :day => 10)
    program = create_program
    program.objectives.planned.create!({:name => 'first objective', :start_at => Clock.now.advance(:weeks => 2), :end_at => Clock.now.advance(:months => 1), :vertical_position => 6})

    backlog_objective = program.objectives.backlog.create!(:name => "second objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 5, program.objectives.find_by_name("second objective").vertical_position
  ensure
    Clock.reset_fake
  end

  def test_should_find_whether_any_existing_objectives_exist_in_the_current_month_when_multiple_objectives_exist_on_the_same_row
    Clock.fake_now(:year => 2012, :month => 10, :day => 10)
    program = create_program
    program.objectives.planned.create!({:name => 'ends in current month', :start_at => Clock.now.advance(:months => -1), :end_at => Clock.now, :vertical_position => 6})
    program.objectives.planned.create!({:name => 'objective not in current month', :start_at => Clock.now.advance(:months => 2), :end_at => Clock.now.advance(:months => 3), :vertical_position => 6})

    backlog_objective = program.objectives.backlog.create!(:name => "new objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 5, program.objectives.find_by_name("new objective").vertical_position
  ensure
    Clock.reset_fake
  end

  def test_should_not_populate_spot_when_surrounded_with_an_existing_objective
    Clock.fake_now(:year => 2012, :month => 10, :day => 10)
    program = create_program
    program.objectives.planned.create!({:name => 'surrounds current month', :start_at => Clock.now.advance(:months => -1), :end_at => Clock.now.advance(:months => 2), :vertical_position => 6})
    assert_equal 6, program.objectives.find_by_name('surrounds current month').vertical_position

    backlog_objective = program.objectives.backlog.create!(:name => "second objective")
    program.plan.plan_backlog_objective(backlog_objective)
    assert_equal 5, program.objectives.find_by_name("second objective").vertical_position
  ensure
    Clock.reset_fake
  end

  def test_should_place_newest_objective_two_weeks_apart_in_the_middle_of_timeline_when_timeline_is_full
    Clock.fake_now(:year => 2012, :month => 10, :day => 10)
    program = create_program
    14.times do |i|
      backlog_objective = program.objectives.backlog.create!(:name => "objective #{i}")
      program.plan.plan_backlog_objective(backlog_objective)
    end
    existing_objective = program.objectives.find_by_vertical_position(6)

    backlog_objective = program.objectives.backlog.create!(:name => "first objective")
    program.plan.plan_backlog_objective(backlog_objective)
    backlog_objective = program.objectives.backlog.create!(:name => "second objective")
    program.plan.plan_backlog_objective(backlog_objective)
    backlog_objective = program.objectives.backlog.create!(:name => "third objective")
    program.plan.plan_backlog_objective(backlog_objective)

    new_objective = program.objectives.find_by_name("first objective")
    assert_equal 6, new_objective.vertical_position
    assert_equal Clock.now.beginning_of_month.advance(:weeks => 2).to_date, new_objective.start_at
    assert_equal Clock.now.beginning_of_month.advance(:weeks => 6).to_date, new_objective.end_at

    new_objective = program.objectives.find_by_name("second objective")
    assert_equal 6, new_objective.vertical_position
    assert_equal Clock.now.beginning_of_month.advance(:weeks => 4).to_date, new_objective.start_at
    assert_equal Clock.now.beginning_of_month.advance(:weeks => 8).to_date, new_objective.end_at

    new_objective = program.objectives.find_by_name("third objective")
    assert_equal 6, new_objective.vertical_position
    assert_equal Clock.now.beginning_of_month.advance(:weeks => 6).to_date, new_objective.start_at
    assert_equal Clock.now.beginning_of_month.advance(:weeks => 10).to_date, new_objective.end_at
  ensure
    Clock.reset_fake
  end

  def test_should_update_planned_objective_position
    program = create_program
    objective_1 = program.objectives.backlog.create!(:name => "first objective")
    program.plan.plan_backlog_objective(objective_1)

    assert_equal 1, objective_1.position
    objective_2 = program.objectives.backlog.create!(:name => "second objective")
    program.plan.plan_backlog_objective(objective_2)
    assert_equal 2, objective_1.reload.position
    assert_equal 1, objective_2.position

    objective_3 = program.objectives.backlog.create!(:name => "third objective")
    program.plan.plan_backlog_objective(objective_3)

    assert_equal 3, objective_1.reload.position
    assert_equal 2, objective_2.reload.position
    assert_equal 1, objective_3.position
  end
end
