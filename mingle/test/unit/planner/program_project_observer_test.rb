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

class ProgramProjectObserverTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_should_be_completed_when_create_work_from_a_card_status_is_done
    card_number = 1
    @project = sp_first_project
    @project.with_card(card_number) do |card|
      card.update_properties('status' => 'closed')
      card.save!
      assert_equal 'closed', card.reload.cp_status
    end
    @program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'closed')

    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    work = @plan.works.first
    assert work.completed?
  end

  def test_should_be_complete_when_card_value_is_greater_than_or_equal_to_done
    card_number = 1
    project = stack_bar_chart_project
    @plan.program.projects << project
    project.with_card(card_number) do |card|
      card.update_properties('status' => 'Closed')
      card.save!
      assert_equal 'Closed', card.reload.cp_status
    end
    @plan.program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'done')
    @plan.assign_cards(project, 1, @program.objectives.first)
    work = @plan.works.first
    assert work.completed?
  end

  def test_should_update_existing_work_completed_status_after_mapped_status_property
    @project = sp_second_project

    @project.with_active_project do |project|
      card = project.cards.find_by_number(1)
      card.update_properties('status' => 'open')
      card.save!
    end
    objective = @program.objectives.first
    @plan.assign_cards(@project, 1, objective)
    work = objective.works.first
    assert !work.completed?

    @plan.program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'open')

    assert work.reload.completed?

    #changed again
    @plan.program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'closed')
    assert !work.reload.completed?
  end


  def test_after_update_when_removing_status_resets_all_work_to_not_completed
    objective = @program.objectives.first
    with_sp_first_project do |project|
      project.cards.find_by_number(1).update_attributes(:cp_status => 'closed')
    end
    @plan.assign_cards(sp_first_project, [1], objective)
    @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')
    assert @plan.works.first.completed
    program_project = @plan.program.program_project(sp_first_project)
    program_project.update_attributes(:done_status => nil, :status_property => nil)
    assert_false @plan.works.first.completed
  end

  def test_should_update_existing_work_completed_status_after_mapped_done_status_reset_to_nil
    @project = sp_second_project

    @project.with_active_project do |project|
      card = project.cards.find_by_number(1)
      card.update_properties('status' => 'closed')
      card.save!
    end

    @plan.assign_cards(@project, 1, @program.objectives.first)
    work = @plan.works.first
    assert !work.completed?

    @plan.program.update_project_status_mapping(@project, :status_property_name => 'status', :done_status => 'closed')

    work.reload
    assert work.completed?

    #changed again
    program_project = @plan.program.program_project(@project)
    program_project.update_attributes(:status_property => nil, :done_status => nil)

    work.reload
    assert !work.completed?
  end

  def test_after_update_done_status_ensures_consistent_completed_status_on_existing_work
    objective = @program.objectives.first
    with_sp_first_project do |project|
      first_card = project.cards.find_by_number(1)
      first_card.update_attributes(:cp_status => 'closed')
      second_card = project.cards.find_by_number(2)
      second_card.update_attributes(:cp_status => 'new')
      
      @plan.assign_cards(sp_first_project, [first_card.number, second_card.number], objective)
      @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'closed')
      assert @plan.works.created_from_card(first_card).first.completed
      assert_false @plan.works.created_from_card(second_card).first.completed
      
      @plan.program.update_project_status_mapping(sp_first_project, :status_property_name => 'status', :done_status => 'open')
      assert @plan.works.created_from_card(first_card).first.completed
      assert_false @plan.works.created_from_card(second_card).first.completed
    end
  end

end
