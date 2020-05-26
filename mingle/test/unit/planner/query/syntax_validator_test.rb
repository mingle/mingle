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

require File.expand_path(File.dirname(__FILE__) + '/../../../simple_test_helper')
require 'mql'
require 'models/plan/query/syntax_validator'

unless ''.respond_to?(:bold)
  class String
    def bold
      "<bold>#{self}</bold>"
    end
  end
end

class SyntaxValidatorTest < Test::Unit::TestCase
  
  def setup
    @validator = Plan::Query::SyntaxValidator.new
  end

  def test_validates_number_as_keyword_is_not_supported
    mql = Mql.parse("SELECT name WHERE iteration = number 2")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /Number.*not supported/i, @validator.errors.first
  end
  
  def test_validates_project_variable_is_not_supported
    mql = Mql.parse("SELECT name WHERE estimate = (best polysemous estimate)")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /project variable.*not supported/i, @validator.errors.first
  end
  
  def test_number_modifer_right_of_equals_not_supported
    mql = Mql.parse("SELECT name WHERE estimate = NUmbER 666")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /NUMBER.*not supported.*/i, @validator.errors.first
  end
  
  def test_number_property_in_where_cond_is_not_supported
    mql = Mql.parse("SELECT name WHERE number > 6")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /number.*in a 'where' clause is not supported/i, @validator.errors.first

    mql = Mql.parse("SELECT name WHERE iteration > property 'number'")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /number.*in a 'where' clause is not supported/i, @validator.errors.first
  end
  
  def test_this_card_is_not_supported
    mql = Mql.parse("SELECT name WHERE iteration > this card")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /this card.*not supported/i, @validator.errors.first
  end
  
  def test_should_be_able_to_use_this_card_as_identifier_in_mql
    mql = Mql.parse("SELECT name WHERE iteration = 'this card'")
    @validator.validate(mql)
    assert_equal 0, @validator.errors.size
    assert_equal [], @validator.errors
  end
  
  def test_this_card_property_is_not_supported
    mql = Mql.parse("SELECT name WHERE iteration > this card.iteration")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /this card.*not supported/i, @validator.errors.first
  end
  
  def test_tagged_with_is_not_supported
    mql = Mql.parse("SELECT name WHERE TAGGED WITH bug")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /tagged with.*not supported/i, @validator.errors.first
  end
  
  def test_in_plan_is_not_supported
    mql = Mql.parse("SELECT name WHERE IN PLAN meerschaum")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /in plan.*not supported/i, @validator.errors.first
  end
  
  def test_not_is_not_supported
    mql = Mql.parse("SELECT name WHERE NOT status = done")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /not.*not supported/i, @validator.errors.first
  end
  
  def test_group_by_is_not_supported
    mql = Mql.parse("SELECT name, status WHERE status = done group by status")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /group by.*not supported/i, @validator.errors.first
  end
  
  def test_order_by_is_not_supported
    mql = Mql.parse("SELECT number WHERE status = done order by number")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /order by.*not supported/i, @validator.errors.first
  end
  
  def test_in_is_not_supported
    mql = Mql.parse("WHERE status IN ('welldone', 'medium')")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /in.*not supported/i, @validator.errors.first
  end
  
  def test_as_of_is_not_supported
    mql = Mql.parse("SELECT number AS OF 'July 12, 2010' WHERE status = done")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /as of.*not supported/i, @validator.errors.first
  end
  
  def test_distinct_is_not_supported
    mql = Mql.parse("SELECT DISTINCT name")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /distinct.*not supported/i, @validator.errors.first
  end
    
  def test_nested_in_is_not_supported
    mql = Mql.parse("SELECT number WHERE number IN (SELECT number WHERE status = done)")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /in.*not supported/i, @validator.errors.first
  end
  
  def test_from_tree_is_not_supported
    mql = Mql.parse("SELECT name, number FROM TREE 'Planning' WHERE Type = Story")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /from.*not supported/i, @validator.errors.first
  end
  
  def test_nonexistent_aggregates_are_not_supported
    mql = Mql.parse("SELECT XYZ(number)")
    @validator.validate(mql)
    assert_equal 1, @validator.errors.size
    assert_match /xyz.*is not a recognized aggregate function/i, @validator.errors.first
    assert @validator.validate(Mql.parse("SELECT SUM(number)"))
    assert @validator.validate(Mql.parse("SELECT AVG(number)"))
    assert @validator.validate(Mql.parse("SELECT Count(*)"))
    assert @validator.validate(Mql.parse("SELECT Min(*)"))
    assert @validator.validate(Mql.parse("SELECT Max(*)"))
  end
end
