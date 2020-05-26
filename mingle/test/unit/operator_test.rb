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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class OperatorTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
  end
  
  def test_description_for_equals_operator_should_be_is
    assert_equal 'is', Operator::Equals.new.description(enumeration_property)
    assert_equal 'is', Operator::Equals.new.description(date_property)
  end
  
  def test_description_for_less_than_operator_with_enumeration_properties_should_be_is_less_than
    assert_equal 'is less than', Operator::LessThan.new.description(enumeration_property)
  end
  
  def test_description_for_greater_than_operator_with_enumeration_properties_should_be_is_greater_than
    assert_equal 'is greater than', Operator::GreaterThan.new.description(enumeration_property)
  end
  
  def test_description_for_less_than_operator_with_date_properties_should_be_is_before
    assert_equal 'is before', Operator::LessThan.new.description(date_property)
  end
  
  def test_description_for_greater_than_operator_with_date_properties_should_be_is_after
    assert_equal 'is after', Operator::GreaterThan.new.description(date_property)
  end
  
  def test_equals_should_compare_on_equality
    equals = Operator::Equals.new
    assert equals.compare("a", "a") # thanks, Aristotle!
    assert !equals.compare("a", "b")
  end
  
  def test_not_equals_should_compare_on_equality
    not_equals = Operator::NotEquals.new
    assert !not_equals.compare("a", "a")
    assert not_equals.compare("a", "b")
  end
  
  def test_equality_override
    assert(Operator::NotEquals.new == Operator::NotEquals.new)
    assert(Operator::NotEquals.new.eql?(Operator::NotEquals.new))
    assert(Operator::NotEquals.new.equal?(Operator::NotEquals.new))
    assert(Operator::NotEquals.new != Operator::Equals.new)
  end
  
  private
  
  def enumeration_property
    @project.find_property_definition_or_nil('iteration')
  end
  
  def date_property
    @project.find_property_definition_or_nil('start date')
  end
  
end
