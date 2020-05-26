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

class CardQueryInPlanConditionDetectionTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @plan = program('simple_program').plan
    @project = sp_first_project
    @project.activate
  end

  def test_can_detect_usage_of_in_plan_in_the_conditions_clause_when_used
    assert CardQuery.parse("SELECT name WHERE IN PLAN 'simple program'").uses_in_plan?
  end

  def test_can_detect_usage_of_in_plan_in_AND_conditions_clause_when_used
    assert CardQuery.parse("SELECT name WHERE status = open AND IN PLAN 'simple program'").uses_in_plan?
  end

  def test_can_detect_not_in_plan
    assert CardQuery.parse("SELECT name WHERE NOT IN PLAN 'simple program'").uses_in_plan?
    assert CardQuery.parse("SELECT name WHERE status = open AND NOT IN PLAN 'simple program'").uses_in_plan?
    assert CardQuery.parse("SELECT name WHERE NOT IN PLAN 'simple program' OR status = open").uses_in_plan?
  end

  def test_can_detect_usage_of_in_plan_in_OR_conditions_clause_when_used
    assert CardQuery.parse("SELECT name WHERE status = open OR IN PLAN 'simple program'").uses_in_plan?
  end

  def test_can_detect_absence_of_in_plan_clause
    assert_false CardQuery.parse("SELECT name").uses_in_plan?
  end

  def test_can_detect_absence_of_in_plan_clause_in_complex_conditions
    assert_false CardQuery.parse("SELECT name WHERE status = open AND number > 3").uses_in_plan?
  end
  
  def test_should_raise_error_when_use_as_of_with_in_plan
    assert_raise_message(CardQuery::DomainException, /Cannot use #{'AS OF'.bold} in conjunction with #{'IN PLAN'.bold}/) do
      CardQuery.parse "SELECT number, name AS OF '06 Aug 2010' WHERE IN PLAN 'simple program'"
    end
  end

end
