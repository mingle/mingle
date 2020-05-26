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

class ObjectiveSnapshotProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper, PlannerForecastHelper

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_adding_a_work_item_should_send_a_message_to_rebuild_snapshot
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)
    clear_message_queue
    with_sp_first_project do |project|
      @plan.assign_card_to_objectives(project, project.cards.first, [objective_a])
    end

    messages = all_messages_from_queue
    assert_equal 1, messages.count
    assert_equal([{:objective_id => objective_a.id, :project_id => sp_first_project.id}],
                 messages.map(&:body_hash))
  end

  def test_deleting_work_item_should_send_message_to_rebuild_snapshot
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)
    with_sp_first_project do |project|
      @plan.assign_card_to_objectives(project, project.cards.first, [objective_a])
    end
    clear_message_queue

    objective_a.works.first.destroy
    messages = all_messages_from_queue
    assert_equal 1, messages.count
    assert_equal([{:objective_id => objective_a.id, :project_id => sp_first_project.id}],
                 messages.map(&:body_hash))
  end


  def test_changing_the_done_status_on_a_project_sends_a_message_to_rebuild_its_snapshots
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)

    with_sp_first_project do |project|
      @plan.program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')
      @plan.assign_card_to_objectives(project, project.cards.first, [objective_a])
    end

    clear_message_queue

    with_sp_first_project do |project|
      @plan.program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'open')
    end

    messages = all_messages_from_queue
    assert_equal 1, messages.count
    assert_equal([{:objective_id => objective_a.id, :project_id => sp_first_project.id}],
                 messages.map(&:body_hash))
  end

  def test_changing_the_order_of_status_values_on_a_project_sends_a_message_to_rebuild_its_snapshots
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)

    with_sp_first_project do |project|
      @plan.program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')
      @plan.assign_card_to_objectives(project, project.cards.first, [objective_a])
    end

    clear_message_queue

    with_sp_first_project do |project|
      status = project.find_property_definition('status')
      values = status.values
      first = values.shift
      status.reorder(values + [first])
    end

    messages = all_messages_from_queue
    assert_equal 1, messages.count
    assert_equal([{:objective_id => objective_a.id, :project_id => sp_first_project.id}],
                 messages.map(&:body_hash))
  end

  def test_changing_the_property_used_for_done_status_of_a_project_sends_a_message_to_rebuild_its_snapshots
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)

    with_sp_first_project do |project|
      @plan.program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')
      @plan.assign_card_to_objectives(project, project.cards.first, [objective_a])
    end

    clear_message_queue

    with_sp_first_project do |project|
      @plan.program.update_project_status_mapping(project, :status_property_name => 'priority', :done_status => 'high')
    end

    messages = all_messages_from_queue
    assert_equal 1, messages.count
    assert_equal([{:objective_id => objective_a.id, :project_id => sp_first_project.id}],
                 messages.map(&:body_hash))
  end

  def test_should_send_rebuild_snapshots_message_when_auto_sync_removed_work_items
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)
    with_sp_first_project do |project|
      card = project.cards.find_by_number('2')
      @plan.assign_card_to_objectives(project, card, [objective_a])
    end
    filter = objective_a.filters.create!(:project => sp_first_project, :params => {:filters => ["[number][is][100000]"]})

    clear_message_queue
    with_sp_first_project do |project|
      filter.sync_work
    end

    messages = all_messages_from_queue
    assert_equal 1, messages.count
    assert_equal([{:objective_id => objective_a.id, :project_id => sp_first_project.id}],
                 messages.map(&:body_hash))
  end

  def test_should_send_rebuild_snapshots_message_when_auto_sync_adds_work_items
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)
    filter = objective_a.filters.create!(:project => sp_first_project, :params => {:filters => ["[number][is][1]"]})
    clear_message_queue
    with_sp_first_project do |project|
      filter.sync_work
    end

    messages = all_messages_from_queue
    assert_equal 1, messages.count
    assert_equal([{:objective_id => objective_a.id, :project_id => sp_first_project.id}],
                 messages.map(&:body_hash))
  end

  def test_should_not_throw_exception_if_objective_has_been_deleted_by_the_time_message_is_processed
    objective_a = @program.objectives.create(:name => "objective_a", :start_at => 2.days.ago, :end_at => 10.days.from_now)
    objective_b = @program.objectives.create(:name => "objective_b", :start_at => 2.days.ago, :end_at => 10.days.from_now)

    with_sp_first_project do |project|
      @plan.assign_card_to_objectives(project, project.cards.first, [objective_a, objective_b])
    end

    clear_message_queue
    ObjectiveSnapshot.enqueue_snapshot_for(@plan)
    objective_a.destroy

    assert_nothing_raised ActiveRecord::RecordNotFound do
      ObjectiveSnapshotProcessor.run_once
    end
  end

  def test_should_create_message_for_unique_objective_project_and_date_combinations
    route(:from => ObjectiveSnapshotProcessor::QUEUE, :to => TEST_QUEUE)
    objective = @program.objectives.create(:name => "rebuild", :start_at => 2.days.ago, :end_at => 10.days.from_now)
    with_sp_first_project do |project|
      @plan.assign_card_to_objectives(project, project.cards.first, [objective])
    end
    messages = all_messages_from_queue
    assert_equal 1, messages.count

    message = messages.first

    assert_equal objective.id, message.body_hash[:objective_id]
    assert_equal sp_first_project.id, message.body_hash[:project_id]
  end

  def test_adding_work_should_create_objective_snapshots
    Clock.fake_now(:year => 2012, :month => 01, :day => 01)
    objective = @program.objectives.create(:name => "rebuild", :start_at => "2012-01-01", :end_at => 10.days.from_now)
    with_sp_first_project do |project|
      @plan.assign_card_to_objectives(project, project.cards.first, [objective])
    end

    Clock.fake_now(:year => 2012, :month => 01, :day => 03)
    assert_difference "ObjectiveSnapshot.count", 2 do
      ObjectiveSnapshotProcessor.run_once
    end
  end

  def test_removing_work_should_rebuild_objective_snapshots
    Clock.fake_now(:year => 2012, :month => 01, :day => 01)
    objective = @program.objectives.create(:name => "rebuild", :start_at => "2012-01-01", :end_at => 10.days.from_now)
    with_sp_first_project do |project|
      @plan.assign_cards(project, project.cards.map(&:number), objective)
    end

    Clock.fake_now(:year => 2012, :month => 01, :day => 02)
    ObjectiveSnapshot.rebuild_snapshots_for(objective.id, sp_first_project.id)

    snapshots = objective.objective_snapshots
    assert_equal 1, snapshots.size
    assert_equal 2, snapshots.first.total

    clear_message_queue(ObjectiveSnapshotProcessor::QUEUE)

    objective.works.first.destroy
    assert_difference "objective.objective_snapshots.last.reload.total", -1 do
      ObjectiveSnapshotProcessor.run_once
    end
  end

  def test_changing_done_definition_for_a_project_should_rebuild_objective_snapshots
    login_as_admin
    @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')

    Clock.fake_now(:year => 2012, :month => 01, :day => 01)
    objective = @program.objectives.create(:name => "rebuild", :start_at => "2012-01-01", :end_at => 10.days.from_now)
    with_sp_first_project do |project|
      card = project.cards.first
      card.update_properties('status' => 'open')
      card.save!

      @plan.assign_card_to_objectives(project, card, [objective])
    end

    Clock.fake_now(:year => 2012, :month => 01, :day => 02)
    ObjectiveSnapshot.rebuild_snapshots_for(objective.id, sp_first_project.id)

    snapshots = objective.objective_snapshots
    
    assert_equal 1, snapshots.size
    assert_equal 1, snapshots.first.total
    assert_equal 0, snapshots.first.completed

    clear_message_queue(ObjectiveSnapshotProcessor::QUEUE)

    @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'new')

    assert_difference "objective.objective_snapshots.last.reload.completed", 1 do
      ObjectiveSnapshotProcessor.run_once
    end
  end
  
  
end
