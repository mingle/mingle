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

class CardWorkTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = create_program
    @plan = @program.plan
    @project = sp_first_project
    @program.projects << [sp_first_project, sp_second_project, sp_unassigned_project]
    create_planned_objective(@program, :name => 'objective a')
    create_planned_objective(@program, :name => 'objective b')
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'closed')
  end

  def test_should_copy_card_name_when_create_work_from_a_card
    work = @plan.works.first
    assert_work_name('sp_first_project card 1', work)
  end

  def test_should_be_complete_when_single_card_is_updated_to_have_status_greater_than_done
    @program.assign(stack_bar_chart_project)
    @program.update_project_status_mapping(stack_bar_chart_project, :status_property_name => 'status', :done_status => 'done')
    card = nil
    stack_bar_chart_project.with_card(1) do |project_card|
      card = project_card
      card.update_properties('status' => 'In Progress')
      card.save!
    end

    @plan.assign_cards(stack_bar_chart_project, 1, @program.objectives.first)
    work = @plan.works.created_from_card(card).first
    assert !work.completed?
    
    stack_bar_chart_project.with_card(1) do |card|
      card.update_properties('status' => 'Closed')
      card.save!
    end
    assert work.reload.completed?
    
    stack_bar_chart_project.with_card(1) do |card|
      card.update_properties('status' => 'New')
      card.save!
    end
    assert !work.reload.completed?
  end

  def test_should_not_update_work_if_non_related_card_attributes_updated
    work = @plan.works.first
    last_updated_at = work.updated_at
    update_card_by_number(@project, {:number => 1, :new_desc => 'new desc'})

    work.reload
    assert_equal last_updated_at.to_s, work.updated_at.to_s
  end

  def test_should_update_work_completed_status_when_update_card_status_mapped
    login_as_admin
    card_number = 1
    @program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'closed')

    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    work = @plan.works.first
    assert !work.completed?

    @project.with_card(card_number) do |card|
      card.update_properties('status' => 'closed')
      card.save!
    end

    work.reload
    assert work.completed?
  end

  def test_delete_card_should_delete_work
    with_sp_first_project do |project|
      project.cards.find_by_number(1).destroy
    end
    assert_equal 0, @plan.works.count
  end

  def test_should_update_existing_work_completed_status_after_mapped_status_property_destroyed
    objective = @program.objectives.planned.create!({:name => 'objective Z', :start_at => "20 Feb 2011", :end_at => "1 Mar 2011"})
    with_new_project do |project|
      setup_property_definitions(:status => ['new', 'open', 'in progress', 'closed'])
      create_card!(:number => 1, :name => 'card 1', :status => 'closed')

      @program.assign(project)
      @program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')

      @plan.assign_cards(project, 1, objective)
      work = objective.works.created_from(project).first
      assert work.completed?

      project.find_property_definition('status').destroy
      assert_nil project.reload.find_property_definition_or_nil('status')
      work.reload
      assert !work.completed?
    end
  end

  def test_bulk_insert_work_into_objective
    Clock.fake_now(:year => 2011, :month => 4, :day => 13)
    objective = @program.objectives.first
    
    @plan.assign_cards(@project, 2, objective)

    assert_equal 2, @plan.works.count
    expected = {:plan => @plan, :project => @project, :objective => objective, :name => 'sp_first_project card 2', :card_number => 2}

    assert_work(expected, @plan.works.created_from_card(OpenStruct.new({:number => 2, :project_id => @project.id})).first)
  ensure
    Clock.reset_fake
  end

  def test_bulk_insert_work_into_objective_without_project_status_property_mapped
    Clock.fake_now(:year => 2011, :month => 4, :day => 13)
    plan = @program.plan
    initial_works_count = plan.works.count
    
    project = sp_unassigned_project
    @program.assign(project)

    objective = @program.objectives.first
    result = plan.assign_cards(project, 1, objective)
    assert_equal 1, result

    assert_equal initial_works_count + 1, plan.works.count
    work = objective.works.created_from(project).first

    expected = {:plan => plan, :project => project, :objective => objective, :name => 'sp_unassigned_project card 1', :card_number => 1, :completed => nil}
    assert_work(expected, work)
  ensure
    Clock.reset_fake
  end

  def test_bulk_insert_should_not_insert_duplicated_card
    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, 1, objective)
    @plan.assign_cards(sp_first_project, 1, objective)
    assert_equal 1, @plan.works.count
  end

  def test_bulk_insert_work_should_ignore_adding_to_same_objective
    objectives = @program.objectives.to_a
    @plan.assign_cards(sp_first_project, 1, objectives[0])
    @plan.assign_cards(sp_first_project, 1, objectives[0])
    assert_equal 1, @plan.works.count
    assert_equal 1, objectives[0].works.size
  end
  
  def test_bulk_insert_work_should_create_work_for_each_objective
    objectives = @program.objectives.to_a
    @plan.assign_cards(sp_first_project, 1, objectives[0])
    @plan.assign_cards(sp_first_project, 1, objectives[1])
    assert_equal 2, @plan.works.count
    assert_equal 1, objectives[1].works.size
    assert_equal 1, objectives[0].works.size
  end

  def test_created_from_cards
    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, 1, objective)
    @plan.assign_cards(sp_second_project, 1, objective)
    with_sp_first_project do |project|
      assert_equal 1, @plan.works.created_from_cards(sp_first_project, CardQuery.parse('number > 0')).count
    end
  end
  
  private

  def assert_work(expected, work)
    unless expected.has_key?(:completed)
      expected[:completed] = false
    end
    assert_equal expected[:card_number],        work.card_number
    assert_equal expected[:name],               work.name
    assert_equal expected[:completed],          work.completed
    assert_equal Clock.now,                     work.created_at
    assert_equal Clock.now,                     work.updated_at
    assert_equal expected[:plan].id,            work.plan_id
    assert_equal expected[:objective].id,       work.objective_id
    assert_equal expected[:project].id,         work.project_id
    
  end

  def assert_work_name(expected_name, work)
    assert_equal expected_name, work.read_attribute('name')
    assert_equal expected_name, work.name
    work.reload
    assert_equal expected_name, work.read_attribute('name')
    assert_equal expected_name, work.name
  end
  
  def update_card_by_number(project, attrs)
    login_as_member
    project.with_card(attrs[:number]) do |card|
      card.update_attribute(:name, attrs[:new_name]) if attrs[:new_name]
      card.update_attribute(:description, attrs[:new_desc]) if attrs[:new_desc]
    end
  end
end
