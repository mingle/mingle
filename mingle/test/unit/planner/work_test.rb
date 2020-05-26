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

class WorkTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_created_from_project
    project = sp_first_project
    with_sp_first_project do |project|
      objective = create_planned_objective @program, :name => "objective new"
      work = @plan.works.created_from(project).create!(:card_number => 1, :objective => objective, :name => project.cards.first.name)
      assert_equal @plan, work.plan
      assert_equal project, work.project
    end
  end

  def test_must_belongs_to_a_project
    objective = create_simple_objective
    work = Work.create(:objective => objective, :card_number => 1)
    assert !work.valid?
    assert_equal "can't be blank", work.errors[:project]
  end

  def test_assign_work_to_multiple_objectives
    project = sp_first_project
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')

    @plan.assign_cards(project, [1], objective_a)
    @plan.assign_cards(project, [1], objective_b)
    assert_equal 1, objective_a.works.count
    assert_equal 1, objective_b.works.count
  end

  def test_renaming_a_card_added_to_multiple_objectives
    project = sp_first_project
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')

    @plan.assign_cards(project, [1], objective_a)
    @plan.assign_cards(project, [1], objective_b)
    
    new_name = 'new name for card one'
    project.with_active_project do |project|
      card = Card.find_by_number 1

      card.name = new_name
      card.save!
      
      works = Work.find_all_by_card_number card.number
      assert_equal 2, works.size
      assert_equal works[0].name, new_name
      assert_equal works[1].name, new_name
    end
  end

  def test_should_be_uniq_in_same_plan_and_project_and_card_number
    with_sp_first_project do |project|
      objective = create_planned_objective @program, :name => "objective x"
      @plan.works.created_from(project).create!(:card_number => 1, :objective => objective, :name => project.cards.first.name)
      work = @plan.works.created_from(project).create(:card_number => 1, :objective => objective)
      assert_false work.valid?
      assert_equal 'has already been taken', work.errors.on(:card_number)
    end
  end
  
  def test_works_scheduled_in_multi_objectives
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    assert_equal 2, @plan.works.filter_by_objective([objectives[0].name, objectives[1].name]).count
  end

  def test_works_not_scheduled_in_objectives
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    assert_equal 2, @plan.works.filter_by_objective([], [objectives[2].name]).count
    assert_equal 1, @plan.works.filter_by_objective([], [objectives[2].name, objectives[1].name]).count
  end

  def test_works_created_from_multi_projects
    project1 = sp_first_project
    project2 = sp_second_project
    objective = @program.objectives.first
    @plan.assign_cards(project1, 1, objective)
    @plan.assign_cards(project2, 1, objective)
    assert_equal 2, @plan.works.filter_by_project([project1.name, project2.name]).count
  end

  def test_works_scheduled_in_objectives_by_name
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    assert_equal 2, @plan.works.filter_by_objective([objectives[0].name, objectives[1].name]).count
  end

  def test_works_scheduled_in_objectives_by_name_should_be_case_insensitive
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    assert_equal 2, @plan.works.filter_by_objective([objectives[0].name.upcase, objectives[1].name.upcase]).count
  end

  def test_filter_works
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])

    assert_equal 1, Work::Filter.decode(["[objective][is][#{objectives[0].name}]"]).apply(@plan.works).count
  end

  def test_filter_works_by_combined_objective_filters
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    assert_equal 2, Work::Filter.decode(["[objective][is][objective a]", "[objective][is not][objective a]"]).apply(@plan.works).count
  end

  def test_filter_works_by_combined_objective_and_project_filters
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])

    assert_equal 0, Work::Filter.decode(["[objective][is][objective a]", "[project][is][sp_second_project]", "[objective][is not][objective a]"]).apply(@plan.works).count
  end

  def test_should_ignore_filter_with_unsupported_attribute
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    
    assert_equal 2, Work::Filter.decode(["[unsupported][is][1]"]).apply(@plan.works).count
  end

  def test_should_do_nothing_to_ignored_filter
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    
    assert_equal 2, Work::Filter.decode(["[objective][is][:ignore]"]).apply(@plan.works).count
  end

  def test_filter_with_unsupported_operation
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    
    assert_equal 0, Work::Filter.decode(["[objective][asdfssadf][1]"]).apply(@plan.works).count
  end

  def test_filter_by_empty_filters
    project = sp_first_project
    objectives = @program.objectives
    @plan.assign_cards(project, 1, objectives[0])
    @plan.assign_cards(project, 2, objectives[1])
    
    assert_equal 2, Work::Filter.decode([]).apply(@plan.works).count
  end

  def test_work_should_be_filtered_by_plan
    objectives = @program.objectives
    @plan.assign_cards(sp_first_project, 1, objectives[0])

    program = create_program
    new_plan = program.plan
    assign_all_work_to_new_objective(program, sp_first_project)

    assert_equal 1, Work::Filter.decode([]).apply(@plan.works).count
  end

  def test_filter_should_be_case_insensitive
    project = sp_first_project
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    @plan.assign_cards(project, 1, objective_a)
    @plan.assign_cards(project, 2, objective_b)
    
    assert_equal 1, Work::Filter.decode(["[Objective][IS][OBJECTIVE a]"]).apply(@plan.works).count
  end

  def test_filter_by_status
    login_as_admin
    project = sp_first_project
    @program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')

    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    @plan.assign_cards(project, 1, objective_a)
    @plan.assign_cards(project, 2, objective_b)
    @plan.assign_cards(sp_second_project, 1, objective_b)

    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      card.update_properties('status' => 'closed')
      card.save!
    end

    assert_equal 1, Work::Filter.decode(["[status][IS][done]"]).apply(@plan.works).count
    assert_equal 1, Work::Filter.decode(["[status][IS][not done]"]).apply(@plan.works).count
    assert_equal 1, Work::Filter.decode(["[status][IS][not mapped]"]).apply(@plan.works).count

    assert_equal 2, Work::Filter.decode(["[status][IS NOT][done]"]).apply(@plan.works).count
    assert_equal 2, Work::Filter.decode(["[status][IS NOT][not done]"]).apply(@plan.works).count
    assert_equal 2, Work::Filter.decode(["[status][IS NOT][not mapped]"]).apply(@plan.works).count
  end

  def test_filter_by_multi_status_filters
    login_as_admin
    project = sp_first_project
    @program.update_project_status_mapping(project, :status_property_name => 'status', :done_status => 'closed')

    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    @plan.assign_cards(project, 1, objective_a)
    @plan.assign_cards(project, 2, objective_b)
    @plan.assign_cards(sp_second_project, 1, objective_b)

    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      card.update_properties('status' => 'closed')
      card.save!
    end

    assert_equal 2, Work::Filter.decode(["[Status][is][not done]", "[Status][is][done]"]).apply(@plan.works).count
    assert_equal 2, Work::Filter.decode(["[Status][is not][not done]", "[Status][is][done]"]).apply(@plan.works).count
  end

  def test_not_in_match_card_query
    @project = sp_first_project
    @objective_a = @program.objectives.find_by_name('objective a')
    @plan.assign_cards(@project, [1, 2], @objective_a)
    @project.with_active_project do |project|
      works = @plan.works.scheduled_in(@objective_a).mismatch(CardQuery.parse("number is 2"))
      assert_equal 1, works.count
      assert_equal 1, works.first.card_number
    end
  end

  def test_assign_a_card_to_multiple_objectives
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')

    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      @plan.assign_card_to_objectives(project, card, [objective_a, objective_b])
    end
    assert_equal 1, objective_a.works.count
    assert_equal 1, objective_b.works.count
  end

  def test_completed_work_as_of_a_date
    Clock.fake_now("2011-02-20")
    program = create_program
    plan = program.plan
    objective_a = create_planned_objective(program, :name => 'objective a')

    with_new_project(:name => "adams_cucumber") do |project|

      setup_property_definitions :status => ['open', 'fixed', 'closed']
      program.projects << project

      program.update_project_status_mapping(project, {:status_property_name => 'status', :done_status => 'closed'})

      card = project.cards.create!(:name => "osito", :card_type_name => project.card_types.first.name)
      card.update_properties('status' => 'closed')
      card.save!

      Clock.fake_now("2011-02-21")
      login_as_admin
      card.update_properties('status' => 'new')
      card.save!

      plan.assign_card_to_objectives(project, card, [objective_a])

      assert_equal [card.number], Work.completed_as_of(plan, project, Date.parse("2011-02-20")).map(&:card_number)
    end
  ensure
    Clock.reset_fake
  end
  
  def test_completed_work_as_of_date_with_same_card_in_different_plans
    Clock.fake_now("2011-02-20")
    program_a = create_program
    program_b = create_program
    
    plan_a = program_a.plan
    plan_b = program_b.plan

    objective_a = create_planned_objective program_a, :name => 'objective a'
    objective_b = create_planned_objective program_b, :name => 'objective b'
    
    with_new_project do |project|
      setup_property_definitions :status => ['open', 'fixed', 'closed']
      program_a.projects << project
      program_b.projects << project
      program_a.update_project_status_mapping(project, {:status_property_name => 'status', :done_status => 'closed'})
      program_b.update_project_status_mapping(project, {:status_property_name => 'status', :done_status => 'closed'})

      card = project.cards.create!(:name => "osito", :card_type_name => project.card_types.first.name)
      card.update_properties('status' => 'closed')
      card.save!

      Clock.fake_now("2011-02-21")
      login_as_admin
      card.update_properties('status' => 'open')
      card.save!

      plan_a.assign_card_to_objectives(project, card, [objective_a])
      plan_b.assign_card_to_objectives(project, card, [objective_b])
      
      assert_equal [card.number], Work.completed_as_of(plan_a, project, Date.parse("2011-02-20")).map(&:card_number)
    end
  end
  
  def test_completed_work_as_of_a_date_with_same_card_number_in_different_project
    Clock.fake_now("2011-02-20")
    program = create_program
    plan = program.plan
    objective_a = create_planned_objective program, :name => 'objective a'
    
    with_new_project(:name => "project with same card number") do |project|

      setup_property_definitions :status => ['open', 'fixed', 'closed']
      program.assign(project)

      program.update_project_status_mapping(project, {:status_property_name => 'status', :done_status => 'closed'})

      card = project.cards.create!(:name => "osito", :card_type_name => project.card_types.first.name)
      card.update_properties('status' => 'closed')
      card.save!

      Clock.fake_now("2011-02-21")
      login_as_admin
      card.update_properties('status' => 'open')
      card.save!

      plan.assign_card_to_objectives(project, card, [objective_a])
    end

    Clock.fake_now("2011-02-20")
    with_new_project(:name => "adams_cucumber") do |project|

      setup_property_definitions :status => ['open', 'fixed', 'closed']
      program.assign(project)

      program.update_project_status_mapping(project, {:status_property_name => 'status', :done_status => 'closed'})

      card = project.cards.create!(:name => "osito", :card_type_name => project.card_types.first.name)
      card.update_properties('status' => 'closed')
      card.save!

      Clock.fake_now("2011-02-21")
      login_as_admin
      card.update_properties('status' => 'new')
      card.save!

      plan.assign_card_to_objectives(project, card, [objective_a])

      assert_equal [card.number], Work.completed_as_of(plan, project, Date.parse("2011-02-20")).map(&:card_number)
    end
  ensure
    Clock.reset_fake
  end

  def test_completed_work_as_of_a_date_having_non_done_status_value
    Clock.fake_now("2011-02-20")
    login_as_admin
    objective_a = @program.objectives.find_by_name('objective a')

    with_new_project(:name => "adams_cucumber") do |project|

      setup_property_definitions :story_status => ['open', 'fixed', 'closed']
      @program.projects << project

      @program.update_project_status_mapping(project, {:status_property_name => 'story_status', :done_status => 'fixed'})

      card = project.cards.create!(:name => "osito", :card_type_name => project.card_types.first.name)
      card.update_properties('story_status' => 'closed')
      card.save!

      Clock.fake_now("2011-02-21")
      login_as_admin
      card.update_properties('story_status' => 'open')
      card.save!

      @plan.assign_card_to_objectives(project, card, [objective_a])
      completed_work = Work.completed_as_of(@plan, project, Date.parse("2011-02-20"))
      assert_equal [card.number], completed_work.map(&:card_number)
    end
  ensure
    Clock.reset_fake
  end


  def test_assign_card_to_objectives_should_delete_work_from_other_objectives
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    objective_c = @program.objectives.find_by_name('objective c')
    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      @plan.assign_cards(project, [1], objective_c)
      @plan.assign_card_to_objectives(project, card, [objective_a, objective_b])
    end
    assert_equal 0, objective_c.works.count
  end

  def test_assign_card_to_objectives_should_not_delete_work_related_to_auto_sync_objectives
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    objective_c = @program.objectives.find_by_name('objective c')
    with_sp_first_project do |project|
      card = project.cards.find_by_number(1)
      @plan.assign_cards(project, [1], objective_c)
      objective_c.filters.create!(:project => project, :params => {:filters => ["[number][is][1]"]})

      @plan.assign_card_to_objectives(project, card, [objective_a, objective_b])
    end
    assert_equal 1, objective_a.works.count
    assert_equal 1, objective_b.works.count

    assert_equal 1, objective_c.works.count
  end
  
  def test_card_number_must_refer_to_existing_card
    with_sp_first_project do
        objective = @program.objectives.first
      card = sp_first_project.cards.find_by_number(1)
      @plan.assign_cards(sp_first_project, card.number, objective)
      work = objective.works.first

      assert work.valid?
      card.destroy

      assert work.invalid?
      assert work.errors.on(:card_number).present?
    end
  end
  
  def test_card_name_must_match
    with_sp_first_project do
        objective = @program.objectives.first
      card = sp_first_project.cards.find_by_number(1)
      @plan.assign_cards(sp_first_project, card.number, objective)
      work = objective.works.first

      assert work.valid?
      card.update_attributes(:name => 'a rose')

      assert work.invalid?
      assert work.errors.on(:card_name).present?
    end
  end
end
