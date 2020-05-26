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

require File.expand_path("../../unit_test_helper", File.dirname(__FILE__))

class ObjectiveTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_should_be_assigned_number
    number_of_objectives = @program.objectives.size
    objective = @program.objectives.backlog.create(:name => 'first', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal number_of_objectives + 1 , objective.number
    assert_equal Objective::Status::BACKLOG , objective.status
    objective = @program.objectives.planned.create(:name => 'second', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal number_of_objectives + 2, objective.number
    assert_equal Objective::Status::PLANNED, objective.status
  end

  def test_should_not_be_able_to_create_objective_without_program
    objective = Objective.create(:name => 'objective')
    assert !objective.valid?
  end

  def test_objective_name_cant_be_blank
    objective = @program.objectives.planned.create(:name => '   ', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert !objective.valid?
    assert_equal "can't be blank", objective.errors[:name]
  end

  def test_should_generate_identifier
    objective = @program.objectives.planned.create!(:name => 'valid name 1234567890', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "valid_name_1234567890", objective.identifier
  end

  def test_should_retain_identifier_on_updating_objective_attributes_other_than_name
    objective = @program.objectives.planned.create!(:name => 'a new objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "a_new_objective", objective.identifier
    objective.end_at = '2011-2-2'
    objective.save!
    assert_equal "a_new_objective", objective.identifier
  end

  def test_should_retain_identifier_on_multiple_updates_without_name_change
    objective = @program.objectives.planned.create!(:name => 'a new objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "a_new_objective", objective.identifier
    objective.end_at = '2011-2-2'
    objective.save!
    objective.end_at = '2011-2-2'
    objective.save!
    assert_equal "a_new_objective", objective.identifier
  end

  def test_should_update_objective_identifier_is_updated_when_name_is_updated
    objective = @program.objectives.planned.create!(:name => 'a new objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "a_new_objective", objective.identifier
    objective.name = "updated name"
    objective.save!
    assert_equal "updated_name", objective.identifier
  end

  def test_should_generate_unique_identifier
    objective = @program.objectives.planned.create!(:name => 'objective name', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "objective_name", objective.identifier

    objective = @program.objectives.planned.create!(:name => 'objective:name', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "objective_name1", objective.identifier

    objective = @program.objectives.planned.create!(:name => 'objective@name', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "objective_name2", objective.identifier
  end

  def test_objective_name_can_have_special_characters
    objective = @program.objectives.planned.create!(:name => 'what!?@#$%^', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert objective.valid?
  end

  def test_objective_name_can_start_with_numbers
    objective = @program.objectives.planned.create!(:name => '1st Feature', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal "objective_1st_feature", objective.identifier
    assert objective.valid?
  end

  def test_validate_objective_name
    objective = @program.objectives.planned.create(:name => '   ', :start_at => '2011-1-1', :end_at => '2011-2-1')

    objective.name = 'valid name with number 1234567890'
    assert objective.valid?
  end

  def test_validate_name_when_80_characters_should_be_valid
    objective = @program.objectives.planned.create(:name => ("a" * 80), :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert objective.valid?
  end

  def test_validate_name_when_81_characters_should_be_invalid
    objective = @program.objectives.planned.create(:name => ("b" * 81), :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert objective.invalid?
    assert_include "Name is too long (maximum is 80 characters)", objective.errors.full_messages
  end

  def test_objective_start_date_should_not_be_blank
    objective = @program.objectives.planned.create(:name => 'name', :start_at => '', :end_at => '2011-2-1')
    assert !objective.valid?
    assert_equal "can't be blank", objective.errors[:start_at]
    assert_equal "Start date can't be blank", objective.errors.full_messages.join
  end

  def test_objective_end_date_should_not_be_blank
    objective = @program.objectives.planned.create(:name => 'name', :start_at => '2011-2-1', :end_at => '')
    assert !objective.valid?
    assert_equal "can't be blank", objective.errors[:end_at]
    assert_equal "End date can't be blank", objective.errors.full_messages.join(", ")
  end

  def test_objective_end_date_should_be_after_start_date
    objective = @program.objectives.planned.create(:name => 'name', :start_at => '2011-2-1', :end_at => '2011-1-1')
    assert !objective.valid?
    assert_equal "should be after start date", objective.errors[:end_at]
    assert_equal "End date should be after start date", objective.errors.full_messages.join(", ")
  end

  def test_should_strip_objective_name_on_save
    objective = create_planned_objective(@program, :name => '  name     should be    stripped ')
    assert_equal 'name should be stripped', objective.name
  end

  def test_objective_progress
    login_as_admin
    objective = @program.objectives.first
    @program.projects.each do |project|
      assign_project_cards(objective, project)
      project.with_active_project do |p|
        @program.update_project_status_mapping(p, :status_property_name => 'status', :done_status => 'closed')
        card = p.cards.first
        card.update_properties(:status => "closed")
        card.save!
      end
    end

    progress = objective.progress
    assert_equal 1, progress["sp_first_project"][:done]
    assert_equal 2, progress["sp_first_project"][:total]
    assert_equal 1, progress["sp_second_project"][:done]
    assert_equal 3, progress["sp_second_project"][:total]
    assert_nil progress["sp_unassigned_project"]
  end

  def test_objective_progress_project_name_should_be_html_escaped
    special_character_named_project = create_project(:name => '<h1>Breakout!</h1>')
    special_character_named_project.with_active_project do |project|
      create_card!(:name => 'card')
      objective = @program.objectives.first
      @program.projects << project
      assign_project_cards(objective, project)

      progress = objective.progress
      assert_equal "&lt;h1&gt;Breakout!&lt;/h1&gt;", progress[progress.keys.first][:name]
    end
  end

  def test_objective_progress_should_start_on_objective_start_date
    login_as_admin
    Clock.fake_now(:year => 2012, :month => 1, :day => 1)
    objective = create_planned_objective(@program, {:name => 'first objective', :start_at => Clock.now, :end_at => 3.days.from_now(Clock.now)})

    @program.projects.each do |project|
      assign_project_cards(objective, project)
      project.with_active_project do |p|
        @program.update_project_status_mapping(p, :status_property_name => 'status', :done_status => 'closed')
        card = p.cards.first
        card.update_properties(:status => "closed")
        card.save!
      end
    end

    progress = objective.progress
  end

  def test_destroy_should_destroy_all_works
    login_as_admin
    objective_to_delete = @program.objectives.find_by_name('objective a')
    untouched_objective = @program.objectives.find_by_name('objective b')
    @program.plan.assign_cards(sp_first_project, [1, 2], objective_to_delete)
    @program.plan.assign_cards(sp_second_project, 1, untouched_objective)
    assert_difference('@program.objectives.planned.count', -1) do
      assert_difference('@program.plan.works.count', -2) do
        assert_no_difference('untouched_objective.works.count') do
          objective_to_delete.destroy
        end
      end
    end
  end

  def test_destroy_should_destroy_all_objective_snapshots
    login_as_admin
    objective_to_delete = @program.objectives.find_by_name('objective a')
    @program.plan.assign_cards(sp_first_project, [1, 2], objective_to_delete)

    assert_difference('ObjectiveSnapshot.count', 1) do
      ObjectiveSnapshot.current_state(objective_to_delete, sp_first_project).save!
    end

    assert_difference('ObjectiveSnapshot.count', -1) do
      objective_to_delete.destroy
    end
  end

  def test_objective_start_and_end_date_should_be_a_duration
    objective_a = @program.objectives.planned.create({:name => 'objective a', :start_at => Time.now, :end_at => 2.days.ago})
    assert_false objective_a.valid?
  end

  def test_objective_name_must_be_unique_within_program
    create_planned_objective(@program, :name => 'objective')
    objective_with_same_name = @program.objectives.planned.create({:name => 'objective', :start_at => Time.now, :end_at => 2.days.from_now})
    assert_false objective_with_same_name.valid?
  end

  def test_objective_name_can_be_same_across_plans
    plan1 = create_program.plan
    plan1.program.projects << first_project
    plan2 = create_program.plan
    plan2.program.projects << sp_second_project
    objective_in_plan1 = plan1.program.objectives.planned.create({:name => 'objective', :start_at => Time.now, :end_at => 2.days.from_now})
    objective_in_plan2 = plan2.program.objectives.planned.create({:name => 'objective', :start_at => Time.now, :end_at => 2.days.from_now})
    assert objective_in_plan1.valid?
    assert objective_in_plan2.valid?
  end

  def test_objective_name_should_be_case_insensitive_uniq_in_plan
    create_planned_objective(@program, :name => 'Feature Name')
    objective = @program.objectives.planned.create({:name => 'feature name', :start_at => Time.now, :end_at => 4.days.from_now})
    assert !objective.valid?
  end

  def test_objective_name_does_not_need_to_be_unique_across_plans
    plan_a = create_program.plan
    plan_a.program.projects << first_project
    plan_b = create_program.plan

    plan_a.program.objectives.planned.create({:name => 'objective', :start_at => Time.now, :end_at => 4.days.from_now})
    objective_with_same_name = plan_b.program.objectives.planned.create({:name => 'objective', :start_at => Time.now, :end_at => 2.days.from_now})
    assert objective_with_same_name.valid?
  end

  def test_objective_name_must_be_unique_ignoring_whitespace
    program = create_program
    program.projects << first_project

    create_planned_objective(program, :name => ' my  objective ')
    objective_with_same_name = program.objectives.planned.create({:name => '     my   objective    ', :start_at => Time.now, :end_at => 2.days.from_now})
    assert_false objective_with_same_name.valid?
  end

  def test_start_at_and_end_at_should_be_date_object
    objective = @program.objectives.first
    assert_equal Date, objective.start_at.class
    assert_equal Date, objective.end_at.class
  end

  def test_change_start_at_should_update_plan_start_at_when_it_is_before_plan
    objective = @program.objectives.first
    objective.start_at = 1.week.ago(@program.plan.start_at)
    objective.save

    assert_equal Date.new(2011, 2, 7), @program.plan.reload.start_at
  end

  def test_change_end_at_should_update_plan_end_at_when_it_is_before_plan
    objective = @program.objectives.first
    objective.end_at = 1.week.since(@program.plan.end_at)
    objective.save

    assert_equal Date.new(2011, 9, 11), @program.plan.reload.end_at
  end

  def test_when_objective_is_within_plan_do_not_change_plan_dates
    objective = @program.objectives.first

    assert_no_difference "@program.plan.reload.start_at" do
      objective.update_attributes(:start_at => 1.week.since(@program.plan.start_at))
    end

    assert_no_difference "@program.plan.reload.end_at" do
      objective.update_attributes(:end_at => 1.week.ago(@program.plan.end_at))
    end
  end

  def test_to_param_should_replace_spaces_in_name_with_underscores
    assert_equal 'foo1_bar', @program.objectives.planned.create!(:name => 'foo1 bar', :start_at => '2011/2/1', :end_at => '2011/2/2').to_param
    assert_equal 'foo2_bar', @program.objectives.planned.create!(:name => ' foo2 bar ', :start_at => '2011/2/1', :end_at => '2011/2/2').to_param
  end

  def test_should_find_program_by_url_identifier
    assert_nil @program.objectives.find_by_url_identifier("not_exist")
    assert_equal @program.objectives.create!(:name => 'foo1 bar', :start_at => '2011/2/1', :end_at => '2011/2/2'),
                 @program.objectives.find_by_url_identifier("foo1_bar")
  end

  def test_to_json
    objective = @program.objectives.planned.create!(:name => 'foo1 bar', :start_at => '2011/2/1', :end_at => '2011/2/2')
    actual_json = ActiveSupport::JSON.decode(objective.to_json)
    assert actual_json["id"]
    assert_equal "foo1 bar", actual_json["name"]
    assert_equal Date.parse("2011/2/1"), Date.parse(actual_json["start_at"])
    assert_equal Date.parse("2011/2/2"), Date.parse(actual_json["end_at"])
  end

  def test_latest_date_with_no_forecasts_should_give_the_end_date_of_the_objective
    objective = @program.objectives.first
    project = sp_second_project
    @program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')
    objective.end_at = Clock.now
    objective.save!

    assert_equal objective.end_at, objective.latest_date_in_objective
  end

  def test_latest_date_with_all_forecasts_should_give_the_farthest_forecast_date
    login_as_admin
    objective = @program.objectives.first

    project_farthest_forecast = sp_first_project
    project_with_forecast = sp_second_project

    create_forecasts_for(:program => @program, :objective => objective, :project => project_farthest_forecast, :cards_to_assign => [1, 2], :cards_to_close => [1])
    create_forecasts_for(:program => @program, :objective => objective, :project => project_with_forecast, :cards_to_assign => [1], :cards_to_close => [1])

    objective.end_at = Clock.now + 1.year
    objective.save!

    assert_equal objective.forecast.for(project_farthest_forecast)[:not_likely].date, objective.latest_date_in_objective
  end

  def test_latest_date_with_partial_forecasts_should_give_the_end_date
    login_as_admin
    objective = @program.objectives.first
    project_with_forecast = sp_first_project
    project_no_forecast = sp_second_project

    create_forecasts_for(:program => @program, :objective => objective, :project => project_with_forecast, :cards_to_assign => [1, 2], :cards_to_close => [1])
    create_forecasts_for(:program => @program, :objective => objective, :project => project_no_forecast, :cards_to_assign => [1], :cards_to_close => [])

    objective.start_at = Date.new(2012, 01, 01)
    objective.end_at = Clock.now + 1.year
    objective.save!

    assert_equal objective.end_at, objective.latest_date_in_objective
  end

  def test_latest_date_with_partial_forecasts_should_give_farthest_forecast
    objective = @program.objectives.first

    project_with_forecast = sp_first_project
    project_no_forecast = sp_second_project

    create_forecasts_for(:program => @program, :objective => objective, :project => project_with_forecast, :cards_to_assign => [1, 2], :cards_to_close => [1])
    create_forecasts_for(:program => @program, :objective => objective, :project => project_no_forecast, :cards_to_assign => [1], :cards_to_close => [])

    objective.end_at = Clock.now
    objective.save!

    forecast_greater_than_end_date = objective.forecast.for(project_with_forecast)[:not_likely].date

    assert_equal forecast_greater_than_end_date, objective.latest_date_in_objective
  end

  def test_deleting_an_objective_should_delete_the_associated_filters
    objective = @program.objectives.first
    objective.filters.create!(:project => sp_first_project, :params => {:filters => ["[number][is][2]"]})
    objective.destroy
    assert_equal [], objective.filters.reload
  end

  def test_deleting_an_objective_should_send_a_synchronize_message
    objective = @program.objectives.first
    project = sp_first_project
    @program.plan.assign_cards(project, [1, 2], objective)
    objective.filters.create!(:project => project, :params => {:filters => ["[number][is][2]"]})
    with_messaging_enable do
      objective.destroy
      messages = Messaging::Mailbox.instance.pending_mails.find_all_by_recipient("mingle.objective.sync")
      assert_equal(1, messages.size)
    end
  end

  def test_start_delayed_when_start_date_and_end_date_are_the_today
    objective = @program.objectives.first
    objective.start_at = Clock.today
    objective.end_at = Clock.today
    project = sp_first_project

    @program.plan.assign_cards(project, [1], objective)

    assert !objective.start_delayed?
  end

  def test_start_delayed_when_start_date_and_end_date_are_the_yesterday
    objective = @program.objectives.first
    objective.start_at = Clock.yesterday
    objective.end_at = Clock.yesterday
    project = sp_first_project

    @program.plan.assign_cards(project, [1], objective)

    assert objective.start_delayed?
  end

  def test_start_delayed_when_objective_end_date_is_before_today
    objective = @program.objectives.first
    objective.start_at = Clock.today - 2
    objective.end_at = Clock.yesterday
    project = sp_first_project

    @program.plan.assign_cards(project, [1], objective)

    assert objective.start_delayed?
  end

  def test_start_delayed_should_return_true_if_no_work_is_completed_past_ten_percent_of_objective_length
    Clock.fake_now(:year => 2012, :month => 1, :day => 1)

    objective = @program.objectives.first
    objective.start_at = Clock.today
    objective.end_at = objective.start_at + 10
    project = sp_first_project

    @program.plan.assign_cards(project, [1], objective)

    assert !objective.start_delayed?

    Clock.fake_now(:year => 2012, :month => 1, :day => 3)
    assert objective.start_delayed?
  end

  def test_start_delayed_should_return_false_if_there_is_no_work
    Clock.fake_now(:year => 2012, :month => 1, :day => 1)

    objective = @program.objectives.first
    objective.start_at = Clock.today
    objective.end_at = objective.start_at + 10

    assert !objective.start_delayed?

    Clock.fake_now(:year => 2012, :month => 1, :day => 3)
    assert !objective.start_delayed?
  end

  def test_start_delayed_should_return_false_if_no_work_is_completed_before_start_date
    objective = @program.objectives.first
    objective.start_at = Clock.tomorrow
    project = sp_first_project

    @program.plan.assign_cards(project, [1], objective)

    assert !objective.start_delayed?
  end

  def test_start_delayed_should_return_false_if_some_work_is_completed_past_start_date
    objective = @program.objectives.first
    objective.start_at = Clock.yesterday
    project = sp_first_project

    @program.plan.assign_cards(project, [1], objective)
    project.with_active_project do
      card = project.cards.find_by_number(1)
      card.update_properties(:status => "closed")
      card.save!
    end

    assert !objective.start_delayed?
  end

  def test_auto_sync_with_project
    objective = @program.objectives.find_by_name('objective a')
    project = sp_first_project
    assert !objective.auto_sync?(project)

    objective.filters.create!(:project => project, :params => {:filters => ["[number][is][1]"]})
    assert objective.auto_sync?(project)
  end

  def test_synced_to_indicate_auto_sync_completion
    objective = @program.objectives.find_by_name('objective a')
    project = sp_first_project
    assert !objective.auto_sync?(project)

    filter = objective.filters.create!(:project => project, :params => {:filters => ["[number][is][1]"]})
    assert_false objective.sync_finished?

    filter.update_attributes(:synced => true)
    assert objective.reload.sync_finished?
  end

  def test_synced_to_indicate_sync_finished_when_no_filter_set
    objective = @program.objectives.find_by_name('objective a')
    project = sp_first_project
    assert !objective.auto_sync?(project)

    assert objective.sync_finished?
  end

  def test_that_objective_identifier_should_not_be_validate_for_uniqueness_across_programs
    objective = @program.objectives.first
    program_b = create_program
    new_objective = program_b.objectives.create!(:name => objective.name, :start_at => Date.today, :end_at => (Date.today + 1))
    assert new_objective.valid?
    assert_equal new_objective.identifier, objective.identifier
  end

  def test_creating_an_objective_with_an_existing_backlog_objective_name_throws_a_validation_error
    @program.objectives.backlog.create(:name => "anacoluthon")
    objective = @program.objectives.planned.create(:name => "anacoluthon", :start_at => Clock.now, :end_at => Clock.now + 1)
    assert_false objective.valid?
    assert_equal 'Name already used for an existing Feature.', objective.errors.full_messages.first
  end

  def test_filter_objectives_started_in_the_current_month
    Clock.fake_now(:year => 2012, :month => 10, :day => 10)
    program = create_program
    program.objectives.planned.create!({:name => 'starts in current month', :start_at => Clock.now, :end_at => Clock.now.advance(:months => 1), :status => Objective::Status::PLANNED})
    program.objectives.planned.create!({:name => 'ends in current month', :start_at => Clock.now.advance(:months => -1), :end_at => Clock.now, :status => Objective::Status::PLANNED})
    program.objectives.planned.create!({:name => 'objective not in current month', :start_at => Clock.now.advance(:months => 2), :end_at => Clock.now.advance(:months => 3), :status => Objective::Status::PLANNED})
    assert_equal 2, program.objectives.in_current_month.size
    assert program.objectives.in_current_month.collect(&:name).include? 'starts in current month'
    assert program.objectives.in_current_month.collect(&:name).include? 'ends in current month'
    assert_false program.objectives.in_current_month.collect(&:name).include? 'objective not in current month'
  ensure
    Clock.reset_fake
  end

  def test_filter_objectives_surrounding_the_current_month
    Clock.fake_now(:year => 2012, :month => 10, :day => 10)
    program = create_program
    program.objectives.planned.create!({:name => 'surrounds current month', :start_at => Clock.now.advance(:months => -1), :end_at => Clock.now.advance(:months => 2), :vertical_position => 6, :status => Objective::Status::PLANNED})
    program.objectives.planned.create!({:name => 'objective not in current month', :start_at => Clock.now.advance(:months => 2), :end_at => Clock.now.advance(:months => 3), :vertical_position => 6, :status => Objective::Status::PLANNED})
    assert_equal 1, program.objectives.in_current_month.size
    assert program.objectives.in_current_month.collect(&:name).include? 'surrounds current month'
  ensure
    Clock.reset_fake
  end


  def test_can_be_created_from_a_planned_objective_that_was_from_backlog
    objective = @program.objectives.backlog.create!(:name => "in backlog", :value => 50, :size => 60, :value_statement => "very good")
    assert_equal Objective::Status::BACKLOG, objective.status
    @program.plan.plan_backlog_objective(objective)
    assert_equal Objective::Status::PLANNED, objective.status
    backlog_objective = objective.move_to_backlog
    assert_equal objective.number, backlog_objective.number
    assert_equal Objective::Status::BACKLOG, backlog_objective.status

  end

  def test_can_be_created_from_a_planned_objective_that_was_not_from_backlog
    objective = @program.objectives.planned.create!(:name => 'azure', :start_at => Date.today, :end_at => 1.year.from_now)
    assert_equal Objective::Status::PLANNED, objective.status

    backlog_objective = objective.move_to_backlog

    assert_equal 'azure', backlog_objective.name
    assert_equal 0, backlog_objective.size
    assert_equal 0, backlog_objective.value
    assert_nil backlog_objective.value_statement
    assert_equal objective.number, backlog_objective.number
    assert_equal Objective::Status::BACKLOG, backlog_objective.status

  end

  def test_filter_newly_planned_objectives
    Clock.fake_now(:year => 2012, :month => 11, :day => 29)
    program = create_program

    obj1 = program.objectives.planned.create!({:name => 'first objective', :start_at => Clock.now, :end_at => Clock.now.advance(:months => 1), :vertical_position => 6})
    program.objectives.planned.create!({:name => 'second objective', :start_at => Clock.now, :end_at => Clock.now.advance(:months => 2), :vertical_position => 6})

    assert_equal 2, program.objectives.newly_planned_objectives.count

    Clock.fake_now(:year => 2012, :month => 11, :day => 30)
    obj1.update_attributes!({:vertical_position => 4})

    assert_equal 1, program.objectives.newly_planned_objectives.count
  ensure
    Clock.reset_fake
  end

  def test_moving_objective_to_backlog_assigns_lowest_priority
    program = create_program
    backlog_objectives = program.objectives.backlog

    # set up some objectives in a known order
    %w[one two three].reverse.each do |name|
      backlog_objectives.create!({:name => name})
    end

    # assert initial priorities
    assert_equal %w[one two three], backlog_objectives.all.map(&:name)

    # plan this objective
    objective = backlog_objectives.find_by_name("two")
    program.plan.plan_backlog_objective objective
    assert_equal %w[one three], backlog_objectives.all.map(&:name)

    # returning the objective to the backlog should rank it as the last priority
    objective.move_to_backlog
    assert_equal %w[one three two], backlog_objectives.all.map(&:name)
  end

  def test_create_objective_having_value_statement_with_new_line
    program = create_program
    value_statement = "line one\n  line two"
    objective = program.objectives.planned.create!(:name => 'test newline', :value_statement => value_statement, :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal value_statement, objective.value_statement
  end

  def test_can_create_objective_with_750_character_value_statement
    program = create_program
    value_statement = "x" * 750
    objective = program.objectives.planned.create!(:name => 'test newline', :value_statement => value_statement, :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal value_statement, objective.value_statement
  end

  def test_should_assign_program_id_if_backlog_objective_table_has_program_id_column
    program = create_program
    value_statement = "x" * 750
    objective = program.objectives.planned.create!(:name => 'test newline', :value_statement => value_statement, :start_at => '2011-1-1', :end_at => '2011-2-1')
    objective.move_to_backlog
    assert 1,program.objectives.backlog.size
    assert program.id,program.reload.objectives.backlog.first.program_id
  end

  def test_planned_objectives_are_sorted_as_last_inserted_on_top
    program = create_program
    value_statement = "x" * 750
    program.objectives.planned.create!(:name => 'A', :value_statement => value_statement, :start_at => '2011-1-1', :end_at => '2011-2-1')
    program.objectives.planned.create!(:name => 'B', :value_statement => value_statement, :start_at => '2011-1-1', :end_at => '2011-2-1')
    program.objectives.planned.create!(:name => 'C', :value_statement => value_statement, :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_equal 3, program.objectives.planned.find_by_name('A').position
    assert_equal 2, program.objectives.planned.find_by_name('B').position
    assert_equal 1, program.objectives.planned.find_by_name('C').position
  end


  def test_objective_moved_from_planned_to_backlog_should_not_have_any_work
    program = create_program
    project = create_project
    program.projects << project
    card_1 = project.cards.create!(name:'card 1 for program plan', card_type_name: project.card_types.first.name)
    card_2 = project.cards.create!(name:'card 2 for program plan', card_type_name: project.card_types.first.name)

    planned_objective = program.objectives.planned.create!(:name => 'planned_objective_with_works', :value_statement => 'value_statement', :start_at => '2011-1-1', :end_at => '2011-2-1')
    program.plan.assign_cards(project, [card_1.number, card_2.number], planned_objective)
    assert_equal 2, planned_objective.works.count
    planned_objective.move_to_backlog
    assert_equal Objective::Status::BACKLOG, planned_objective.status
    assert_equal 0, planned_objective.works.count
  end

  def test_should_set_default_objective_type_if_not_set
    program = create_program

    objective = program.objectives.backlog.create!(:name => 'new objective')

    assert_equal(program.default_objective_type, objective.objective_type)
  end

  private
  def create_forecasts_for(options)
    program = options[:program]
    project = options[:project]
    cards_to_assign = options[:cards_to_assign]
    cards_to_close = options[:cards_to_close]
    objective = options[:objective]

    program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')

    Clock.fake_now(:year => 2012, :month => 1, :day => 1)

    cards_to_assign.each do |card|
      program.plan.assign_cards(project, [card], objective)
    end

    ObjectiveSnapshot.current_state(objective, project).save!
    Clock.fake_now(:year => 2012, :month => 1, :day => 2)

    project.with_active_project do |project|
      cards_to_close.each do |card|
        card = project.cards.find_by_number(card)
        card.update_properties(:status => "closed")
        card.save!
      end
    end

  end

end
