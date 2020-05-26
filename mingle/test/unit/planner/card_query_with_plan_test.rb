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

class CardQueryWithPlanTest < ActiveSupport::TestCase
  
  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end
  
  def test_count_cards_in_plan_when_there_are_some_projects_and_plans
    program_a = create_program('program_a')
    program_b = create_program('program_b')
    
    with_new_project do |project|
      create_card!(:name => 'card in program A')
      assign_all_work_to_new_objective(program_a, project)
      create_card!(:name => 'card not assigned to program a')
    end

    with_new_project do |project|
      create_card!(:name => 'card in program B')
      assign_all_work_to_new_objective(program_b, project)
      create_card!(:name => 'card not in program b')
      assert_equal '1', CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'program_b'").single_value
    end
  end

  def test_count_cards_in_plan_when_one_project_is_related_with_multi_plans
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      card2 = create_card!(:name => 'card 2')
      program_a = create_program('program_a')
      program_b = create_program('program_b')
      plan_a = program_a.plan
      plan_b = program_b.plan
      program_a.projects << project
      program_b.projects << project
      
      objective = create_planned_objective(program_a, {:name => 'objective a'})
      plan_a.assign_cards(project, card1.number, objective)

      objective = create_planned_objective(program_b, {:name => 'objective b'})
      program_b.plan.assign_cards(project, card2.number, objective)

      create_card!(:name => 'card not in plan a or b')

      assert_equal '1', CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'program_b'").single_value
    end
  end

  def test_count_cards_in_multi_plans
    with_new_project do |project|
      assign_cards_to_plan(create_program('program_a'), project, create_card!(:name => 'card 1').number)
      assign_cards_to_plan(create_program('program_b'), project, create_card!(:name => 'card 2').number)
      assign_cards_to_plan(create_program('program_c'), project, create_card!(:name => 'card 3').number)

      create_card!(:name => 'card not in plan a, b or c')
      assert_equal '2', CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'program_a' OR IN PLAN 'program_b'").single_value
      assert_equal '0', CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'program_a' AND IN PLAN 'program_b'").single_value
    end
  end

  def test_count_cards_in_multi_plans_scenario2
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      card2 = create_card!(:name => 'card 2')
      card3 = create_card!(:name => 'card 3')

      assign_cards_to_plan(create_program('program_a'), project, [card1.number, card2.number])
      assign_cards_to_plan(create_program('program_b'), project, [card2.number, card3.number])
      assign_cards_to_plan(create_program('program_c'), project, [card3.number])

      create_card!(:name => 'card not in plan a, b or c')
      assert_equal '1', CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'program_a' AND NOT IN PLAN 'program_b'").single_value
    end
  end

  def create_new_objective(program, project)
    program.projects << project
    create_planned_objective(program, {:name => "great things"})
  end

  def assign_cards_to_plan(program, project, cards)
    objective = create_new_objective(program, project)
    program.plan.assign_cards(project, cards, objective)
  end

  def test_not_in_plan_in_mql
    with_new_project do |project|
      create_card!(:name => 'card 1')
      program_a = create_program('program_a')
      objective = create_new_objective(program_a, project)
      program_a.plan.assign_cards(project, project.cards.collect(&:number), objective)

      create_card!(:name => 'card not in plan a')
      assert_equal 'card not in plan a', CardQuery.parse("SELECT name WHERE NOT IN PLAN 'program_a'").single_value
    end

    with_new_project do |project|
      create_card!(:name => 'card 2')

      program_b = create_program('program_b')
      objective = create_new_objective(program_b, project)
      program_b.plan.assign_cards(project, project.cards.collect(&:number), objective)

      create_card!(:name => 'card not in plan b')
      assert_equal 'card not in plan b', CardQuery.parse("SELECT name WHERE NOT IN PLAN 'program_b'").single_value
    end
  end

  def test_property_named_plan_still_works
    with_new_project do |project|
      UnitTestDataLoader.setup_property_definitions(:plan => ['a', 'b'])
      card1 = create_card!(:name => 'card 1', :plan => 'a')
      card2 = create_card!(:name => 'card 1', :plan => 'b')
      assert_equal '1', CardQuery.parse("SELECT COUNT(*) WHERE plan is 'a'").single_value
    end
  end
  
  def test_plan_name_should_be_case_insensitive
    with_new_project do |project|
      program = program('simple_program')
      plan = program.plan
      plan.program.projects << project
      plan.assign_cards(project, create_card!(:name => 'card 1').number, program.objectives.first)
      assert_equal '1', CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'Simple PROGRAM'").single_value
    end
  end
  
  def test_should_work_with_original_condition_clause
    with_new_project do |project|
      UnitTestDataLoader.setup_property_definitions(:status => ['open', 'closed'])
      create_card!(:name => 'card 1', :status => 'open')
      program = program('simple_program')
      objective = create_new_objective(program, project)
      program.plan.assign_cards(project, project.cards.collect(&:number), objective)
      
      create_card!(:name => 'card 2', :status => 'open')
      assert_equal '2', CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN \"simple program\" OR status is open").single_value
    end
    
  end
  
  def test_should_raise_error_when_there_is_no_such_plan
    with_first_project do |project|
      assert_raise_message CardQuery::PlanNotExistError, /Plan with name #{'plan xxx'.bold} does not exist/ do
        CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'plan xxx'").single_value
      end
    end
  end
  
  def test_should_raise_error_when_there_is_no_such_plan_in_project
    with_first_project do |project|
      assert_raise_message CardQuery::PlanNotExistError, /Plan with name #{'simple program'.bold} does not exist/ do
        CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'simple program'").single_value
      end
    end
  end
  
  def test_should_allow_plan_name_to_be_plan
    with_sp_first_project do |project|
      program = create_program('plan')
      assign_all_work_to_new_objective(program, project)
      assert_equal project.cards.count.to_s, CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'plan'").single_value
    end
  end
  
  def test_should_allow_plv_name_to_be_plan
    with_first_project do |project|
      status_prop_def = project.find_property_definition('Status')
      plv = create_plv!(project, :name => 'plan', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'plan', :property_definition_ids => [status_prop_def.id])
      @program.projects << project
      @plan.assign_cards(project, create_card!(:name => 'card 1', :status => 'plan').number, @program.objectives.first)
      assert_equal '1', CardQuery.parse("SELECT COUNT(*) WHERE status is (plan)").single_value
      assert_equal '1', CardQuery.parse("SELECT COUNT(*) WHERE in PLAN 'simple program' OR status is (plan)").single_value
    end
  end
  
  def test_should_raise_error_when_use_as_of
    with_first_project do |project|
      @program.projects << project
      assert_raise_message(CardQuery::DomainException, /Cannot use #{'AS OF'.bold} in conjunction with #{'IN PLAN'.bold}/) do
        CardQuery.parse "SELECT count(*) AS OF '06 Aug 2010' WHERE IN PLAN 'simple program'"
      end
    end
  end
  
  def test_daily_history_chart_should_not_allow_in_plan_as_chart_condition
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: IN PLAN 'program_a'
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: heyo
    }} }

    with_first_project do |project|
      program = create_program('program_a')
      program.projects << project
      assert_raise_message Macro::ProcessingError, /IN PLAN.*\sis not supported in the daily history chart.$/ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end
  
  def test_daily_history_chart_should_not_allow_in_plan_as_series_condition
    template = %{ {{
      daily-history-chart
        aggregate: COUNT(*)
        chart-conditions: 
        start-date: 14 May 2009
        end-date: 15 May 2009
        series:
          - label: heyo
            conditions: IN PLAN 'program_a'
    }} }

    with_first_project do |project|
      program = create_program('program_a')
      program.projects << project
      assert_raise_message Macro::ProcessingError, /IN PLAN.*\sis not supported in the daily history chart./ do
        card = project.cards.create!(:name => 'card one', :card_type_name => "card", :cp_start_date => '2001-09-07')
        chart = Chart.extract(template, 'daily-history-chart', 1, :content_provider => card)
      end
    end
  end

  def test_should_not_be_cachable_for_mql_includes_plan_info
    with_new_project do |project|
      create_card!(:name => 'card 2')
      @program.projects << project
      @plan.assign_cards(project, project.cards.collect(&:number), @program.objectives.first)
      create_card!(:name => 'card not in existing objectives')
      assert_equal false, CardQuery.parse("SELECT COUNT(*) WHERE IN PLAN 'simple program'").can_be_cached?
    end
  end
end
