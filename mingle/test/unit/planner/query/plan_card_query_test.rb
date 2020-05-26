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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

# !case insensitive for card name
# ! enum prop: text, number
# ! predefined number
# ! date prop
# ! not eq should include null values
# !validations:
#    !where condition does not support number keyword (not in this test case)
#    !non-num prop in aggregate
# select count(*), count(number) need alias name to seperate the result
class PlanCardQueryTest < ActiveSupport::TestCase
  def setup
    @program = program('simple_program')
    @plan = @program.plan
    login_as_admin
  end

  def test_select_a_predefined_property_value
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal ['1'], query('select number')
  end

  def test_select_an_enum_property_value
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal [nil], query('select status')
    update_sp_first_project_card(:number => 1, 'status' => 'new')
    assert_equal ['new'], query('select status')
  end

  def test_select_numeric_property_value
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal [nil], query('select Pi')
    update_sp_first_project_card(:number => 1, 'pi' => 1)
    assert_equal ['1'], query('select Pi')
  end

  def test_select_property_name_should_be_case_insensitive
    assert_equal [], query('select staTUS')
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'status' => 'new')
    assert_equal ['new'], query('select staTUS')
  end

  def test_select_multiple_properties
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'status' => 'new')
    update_sp_first_project_card(:number => 1, 'estimate' => 1)
    assert_equal([{"status" => "new", "estimate" => "1"}], query('select sTATus, eSTImate', :select_all))
  end

  def test_select_card_property_cross_projects
    @plan.program.projects << sp_unassigned_project
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_second_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_unassigned_project, 1, @program.objectives.first)

    update_sp_first_project_card(:number => 1, 'status' => 'open')
    update_card(sp_second_project, :number => 1, 'status' => 'new')
    update_card(sp_unassigned_project, :number => 1, 'status' => 'closed')

    assert_equal ['closed', 'new', 'open'], query('select status').sort
  end

  def test_select_count
    assert_equal ['0'], query('select count(*)')
    assert_equal [], query('select count(*), number')
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal ['1'], query('select count(*)')
    assert_equal [{"name"=>"sp_first_project card 1", "count(*)"=>"1"}], query('select count(*), name', :select_all)
    update_sp_first_project_card(:number => 1, 'status' => 'new')
    assert_equal ['1'], query('select count(*) where status = new')
    assert_equal ['0'], query('select count(*) where status = open')
  end

  def test_select_sum
    assert_equal ['0'], query('select sum(number)')
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal [{"name"=>"sp_first_project card 1", "sum(number)"=>"1"}], query('select sum(number), name', :select_all)
    update_sp_first_project_card(:number => 1, 'status' => 'new')
    assert_equal ['1'], query('select SUM(number) where status = new')
    assert_equal ['0'], query('select SUM(number) where status = open')
    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    assert_equal ['3'], query('select sum(number)')
  end

  def test_select_avg_numeric_enum_prop_definition
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'pi' => 1)
    update_sp_first_project_card(:number => 2, 'pi' => 3)
    assert_equal [2], query('select avg(pi)').collect(&:to_i)
  end

  def test_select_min_numeric_enum_prop_definition
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'pi' => 1)
    update_sp_first_project_card(:number => 2, 'pi' => 3)
    assert_equal [1], query('select min(pi)').collect(&:to_i)
  end

  def test_select_max_numeric_enum_prop_definition
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'pi' => 1)
    update_sp_first_project_card(:number => 2, 'pi' => 3)
    assert_equal [3], query('select max(pi)').collect(&:to_i)
  end

  def test_select_2_same_aggregate_function_with_different_properties
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'pi' => 1)
    update_sp_first_project_card(:number => 2, 'pi' => 3)
    assert_equal [{'max(pi)' => '3', 'max(number)' => '2'}], query('select max(pi), max(number)', :select_all)
  end

  def test_should_be_invalid_to_have_number_prop_in_where_cond
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_raise Plan::Query::SyntaxValidator::Error do
      query('select number where number = 0')
    end
  end

  def test_string_type_property_definition_comparison
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal [], query('select number where name = "card name"')
    assert_equal ['1'], query('select number where name = "sp_first_project card 1"')
    assert_equal [], query('select number where name > "sp_first_project card 1"')
    assert_equal [], query('select number where name is null')
    assert_equal ['1'], query('select number where name is not null')
  end

  def test_a_simple_where_text_enum_property_condition
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    
    assert_equal [], query('select number where status = new')
    assert_equal ['1'], query('select number where status = null')
    update_sp_first_project_card(:number => 1, 'status' => 'new')
    assert_equal ['1'], query('select number where status = new')
    assert_equal [], query('select number where status > new')
    assert_equal ['1'], query('select number where status < open')
    assert_equal ['1'], query('select number where status <= open')
    assert_equal [], query('select number where status >= open')
    assert_equal ['1'], query('select number where status >= new')
    assert_equal ['0'], query('select count(*) where status = null')
  end

  def test_select_with_2_enum_prop_conditions
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_second_project, 1, @program.objectives.first)
    update_card(sp_first_project, :number => 1, :status => 'open')
    update_card(sp_second_project, :number => 1, :priority => 'medium')

    assert_equal [], query('select name where status > new aNd priority > low')
    assert_equal ['sp_first_project card 1', 'sp_second_project card 1'].sort, query('select name where status > new OR priority > low').sort
  end

  def test_a_simple_where_numeric_enum_property_condition
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)

    assert_equal [], query('select number where pi = 1')
    update_sp_first_project_card(:number => 1, 'pi' => 1)
    assert_equal ['1'], query('select number where pi = 1')
    assert_equal [], query('select number where pi > 1')
    assert_equal ['1'], query('select number where pi < 4')
    assert_equal ['1'], query('select number where pi <= 4')
    assert_equal [], query('select number where pi >= 4')
    assert_equal ['1'], query('select number where pi >= 1')
    assert_equal ['1'], query('select number where pi > 0')
    assert_equal ['1'], query('select count(*) where pi = property pi')
    assert_equal ['0'], query('select count(*) where pi != property pi')
    assert_equal ['0'], query('select count(*) where pi = null')

    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    assert_equal ['1'], query('select count(*) where pi = null')
  end

  def test_enum_property_value_in_condition_should_be_case_insensitive
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'status' => 'new')
    assert_equal ['1'], query('select number where status = nEw')
  end

  def test_select_date_property_value
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'due date' => 'Oct 21 2010')
    assert_equal ['21 Oct 2010'], query('select "due date"')
  end

  def test_date_property_condition
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'due date' => 'Oct 21 2010')
    assert_equal ['1'], query('select number where "due date" = "Oct 21 2010"')
    assert_equal ['1'], query('select number where "due date" != "Oct 20 2010"')
    assert_equal ['1'], query('select number where "due date" > "Oct 20 2010"')
    assert_equal ['1'], query('select number where "due date" < "Oct 22 2010"')
    assert_equal ['1'], query('select number where "due date" >= "Oct 21 2010"')
    assert_equal ['1'], query('select number where "due date" <= "Oct 21 2010"')
    assert_equal ['1'], query('select number where "due date" <= toDAY')
    assert_equal [], query('select number where "due date" = "Oct 20 2010"')
    assert_equal [], query('select number where "due date" != "Oct 21 2010"')
    assert_equal [], query('select number where "due date" < "Oct 21 2010"')
    assert_equal [], query('select number where "due date" > "Oct 21 2010"')
    assert_equal [], query('select number where "due date" >= "Oct 22 2010"')
    assert_equal [], query('select number where "due date" <= "Oct 20 2010"')
  end

  def test_compare_2_date_property
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_sp_first_project_card(:number => 1, 'due date' => 'Oct 21 2010')
    assert_equal [],    query('select number where "due date" =  PROPERTY "created on"')
    assert_equal ['1'], query('select number where "due date" != PROPERTY "created on"')
    assert_equal [],    query('select number where "due date" >  PROPERTY "created on"')
    assert_equal ['1'], query('select number where "due date" <  PROPERTY "created on"')
    assert_equal [],    query('select number where "due date" >= PROPERTY "created on"')
    assert_equal ['1'], query('select number where "due date" <= PROPERTY "created on"')

    update_sp_first_project_card(:number => 1, 'due date' => Clock.today)
    assert_equal ['1'], query('select number where "due date" = PROPERTY "modified on"')
  end

  def test_name_comparision_should_be_case_insensitive
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal ['1'],    query('select number where name = "SP_FIRST_PROJECT card 1"')
  end

  def test_not_eq_comparision_should_include_null_values
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal ['1'], query('select number where status != new')
    assert_equal ['1'], query('select number where "due date" != "Oct 21 2010"')
    assert_equal ['1'], query('select number where pi != 3')

    update_sp_first_project_card(:number => 1, 'status' => 'new')
    update_sp_first_project_card(:number => 1, 'due date' => 'oct 21 2010')
    update_sp_first_project_card(:number => 1, 'pi' => 3)
    assert_equal [], query('select number where status != new')
    assert_equal [], query('select number where "due date" != "Oct 21 2010"')
    assert_equal [], query('select number where pi != 3')

    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    assert_equal ['2'], query('select number where status != new')
    assert_equal ['2'], query('select number where "due date" != "Oct 21 2010"')
    assert_equal ['2'], query('select number where pi != 3')
    assert_equal ['1'], query('select count(*) where pi != null')
  end

  def test_validate_syntax_when_generating_sql_ast
    assert_raise Plan::Query::SyntaxValidator::Error do
      query('select number from tree abc')
    end
  end

  def test_should_given_error_when_no_project_associated_with_plan
    plan = create_program.plan
    assert_raise Plan::Query::NoProjectAssociatedError do
      Plan::Query::PlanCardQuery.new(plan, Mql.parse('select number')).sql_ast
    end
  end

  def test_should_raise_error_when_data_type_of_property_definition_in_query_is_diff_in_program_projects
    proj = with_new_project do |project|
      setup_numeric_property_definition('ESTImate', [1, 2, 4, 8])
    end
    @plan.program.projects << proj
    assert_raise Plan::Query::DiffPropDefDataTypeError do
      query('select estimate')
    end
  end

  def test_mql_raise_error_for_aggregating_non_numeric_properties
    assert_raise Plan::Query::AggregateNonNumericProperty do
      query('SELECT SUM(status)')
    end
  end

  def test_should_give_error_when_property_does_not_exist
    assert_raise(Project::NoSuchPropertyError) { query("SELECT name WHERE total_polysemous_garbage = 1") }
    assert_raise(Project::NoSuchPropertyError) { query("SELECT total_polysemous_garbage") }
    assert_raise(Project::NoSuchPropertyError) { query("SELECT sum(total_polysemous_garbage)") }
    assert query("SELECT count(*)")
  end

  def test_should_only_query_work_in_current_plan
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    workless_program = create_program
    workless_plan = workless_program.plan
    workless_program.projects << sp_first_project
    assert_equal [], workless_plan.query_works('select name').single_values
  end

  def test_a_complex_where_boolean_condition
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal ['1'], query("select count(*) where (type = 'card' or name = 'sp_first_project_1') and (type = 'card' and type >= 'card')")
  end

  def test_extract_select_columns_with_property_types
    q = Plan::Query::PlanCardQuery.new(@plan, Mql.parse('select number'))
    assert_equal [Ast::Node.new(:column, :name => 'number', :type => IntegerPropertyDefinition, :numeric => true)], q.select_columns
  end

  def test_extract_select_columns_should_only_care_about_select_statement
    q = Plan::Query::PlanCardQuery.new(@plan, Mql.parse('select number where status = new'))
    assert_equal [Ast::Node.new(:column, :name => 'number', :type => IntegerPropertyDefinition, :numeric => true)], q.select_columns
  end

  def test_extract_select_columns_have_aggregate_func
    q = Plan::Query::PlanCardQuery.new(@plan, Mql.parse('select max(number), number'))
    number_column = Ast::Node.new(:column, :name => 'number', :type => IntegerPropertyDefinition, :numeric => true)
    aggregate_column = Ast::Node.new(:aggregate, :property => number_column.dup, :numeric => true, :name => 'max(number)', :function => 'max')
    assert_equal 2, q.select_columns.size
    assert_equal aggregate_column, q.select_columns[0]
    assert_equal number_column, q.select_columns[1]
  end

  def test_order_of_select_columns
    q = Plan::Query::PlanCardQuery.new(@plan, Mql.parse('select number, "DUE date", status'))
    expected = [
      Ast::Node.new(:column, :name => 'number', :type => IntegerPropertyDefinition, :numeric => true),
      Ast::Node.new(:column, :name => 'DUE date', :type => DatePropertyDefinition, :numeric => false),
      Ast::Node.new(:column, :name => 'status', :type => EnumeratedPropertyDefinition, :numeric => false)
    ]
    assert_equal expected, q.select_columns
  end

  def test_select_columns_should_do_validation
    q = Plan::Query::PlanCardQuery.new(@plan, Mql.parse('select abc from tree efd'))
    assert_raise Plan::Query::SyntaxValidator::Error do
      q.select_columns
    end
  end

  def test_should_be_able_to_query_with_hidden_prop
    with_sp_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:hidden, true)
      project.reload
    end
    assert_equal ['0'], query("select count(*) where status is null")
  end

  def query(mql, selection=:single_values) #:select_all
    pql= create_query(mql).sql_ast

    selector = Plan::Query::Selector.new(Plan.connection, create_query(mql), self)
    puts selector.sql if $debug
    if selection == :single_values
      selector.single_values
    else
      selector.values
    end
  end

  def create_query(mql)
    Plan::Query::PlanCardQuery.new(@plan, Mql.parse(mql))
  end

  def format_date(date)
    @plan.format_date(date)
  end

  def format_number(number)
    number.to_s.to_num(@plan.precision).to_s
  end

  def update_sp_first_project_card(properties)
    update_card(sp_first_project, properties)
  end

  def update_card(project, properties)
    card_number = properties.delete(:number)
    project.with_active_project do |project|
      card = project.cards.find_by_number(card_number)
      card.update_properties(properties)
      card.save!
    end
  end
end
