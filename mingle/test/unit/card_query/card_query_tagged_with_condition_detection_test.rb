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

class CardQueryTaggedWithConditionDetectionTest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end

  def test_can_detect_usage_of_tagged_with_in_the_conditions_clause_when_used
    assert CardQuery.parse("SELECT name WHERE TAGGED WITH 'foo'").uses_tagged_with?
  end

  def test_can_detect_usage_of_tagged_with_in_complex_and_conditions_clause_when_used
    assert CardQuery.parse("SELECT name WHERE status = open AND TAGGED WITH 'foo'").uses_tagged_with?
  end

  def test_can_detect_not_tagged_with
    assert CardQuery.parse("SELECT name WHERE NOT TAGGED WITH 'foo'").uses_tagged_with?
    assert CardQuery.parse("SELECT name WHERE status = open AND NOT TAGGED WITH 'foo'").uses_tagged_with?
    assert CardQuery.parse("SELECT name WHERE NOT TAGGED WITH 'foo' OR status = open").uses_tagged_with?
  end

  def test_can_detect_usage_of_tagged_with_in_complex_or_conditions_clause_when_used
    assert CardQuery.parse("SELECT name WHERE status = open OR TAGGED WITH 'foo'").uses_tagged_with?
  end

  def test_can_detect_tagged_with_not_being_in_the_conditions_clause
    assert_false CardQuery.parse("SELECT name").uses_tagged_with?
  end

  def test_can_detect_tagged_with_not_being_in_complex_conditions_clause
    assert_false CardQuery.parse("SELECT name WHERE status = open AND number > 3").uses_tagged_with?
  end
  
  def test_should_raise_error_when_use_as_of_with_tagged_with
    assert_raise_message(CardQuery::DomainException, /Cannot use #{'AS OF'.bold} in conjunction with #{'TAGGED WITH'.bold}/) do
      CardQuery.parse "SELECT number, name AS OF '06 Aug 2010' WHERE TAGGED WITH a"
    end
  end

end
