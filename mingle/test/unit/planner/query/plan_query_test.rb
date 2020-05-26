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

class PlanQueryTest < ActiveSupport::TestCase
  def setup
    @program = program('simple_program')
    @plan = @program.plan
    login_as_admin
  end

  def test_single_value_should_be_formated_as_string
    assert_equal '0', @plan.query_works('select count(*)').single_value
    assert_equal nil, @plan.query_works('select number').single_value
  end

  def test_single_date_value_should_be_formated_as_plan_date_format
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    update_card(sp_first_project, :number => 1, 'due date' => 'Oct 21 2010')
    assert_equal '21 Oct 2010', @plan.query_works('select "due date"').single_value
  end

  def test_aggregates_should_work_correctly_even_with_no_work
    assert_equal "0", @plan.query_works("SELECT SUM('number')").single_value
    assert_equal "0", @plan.query_works("SELECT AVG('number')").single_value
    assert_equal "0", @plan.query_works("SELECT count(*)").single_value
    assert_equal nil, @plan.query_works("SELECT MIN('pi')").single_value
    assert_equal nil, @plan.query_works("SELECT MAX('pi')").single_value
  end

  def test_numeric_should_be_formated_with_plan_precision
    update_card(sp_first_project, :number => 1, :pi => 1)
    update_card(sp_first_project, :number => 2, :pi => 4)
    update_card(sp_second_project, :number => 1, :pi => 3)
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    assert_equal "2.5", @plan.query_works('SELECT avg(pi)').single_value
    @plan.assign_cards(sp_second_project, 1, @program.objectives.first)
    assert_equal "2.67", @plan.query_works('SELECT avg(pi)').single_value
  end

  def test_query_works_values
    update_card(sp_first_project, :number => 1, :pi => 1)
    update_card(sp_first_project, :number => 2, :pi => 4)
    update_card(sp_second_project, :number => 1, :pi => 3)
    @plan.assign_cards(sp_first_project, 1, @program.objectives.first)
    assert_equal [{"pi" => "1"}], @plan.query_works('SELECT Pi').values
    @plan.assign_cards(sp_first_project, 2, @program.objectives.first)
    @plan.assign_cards(sp_second_project, 1, @program.objectives.first)
    assert_equal [{"avg(pi)" => "2.67"}], @plan.query_works('SELECT avg(pi)').values
    assert_equal [{"count(*)" => "3", "count(pi)" => '3'}], @plan.query_works('SELECT count(pi), count(*)').values
  end

  def test_select_properties_named_user_or_date_which_are_keywords_and_have_error_in_oracle
    with_new_project do |project|
      setup_user_definition('user')
      setup_date_property_definition('date')

      plan = create_program.plan
      plan.program.projects << project
      assert_equal [], plan.query_works('SELECT user').values
      assert_equal [], plan.query_works('SELECT date').values
    end
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
