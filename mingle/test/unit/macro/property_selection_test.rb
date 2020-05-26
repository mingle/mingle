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

class PropertySelectionTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @project = pie_chart_test_project
    @project.activate
  end

  def test_from_should_initialize_property_selection_from_query
    data_query = CardQuery.parse('SELECT Feature, Count(*)')
    properties_selection = PropertySelection.from(data_query)
    assert_not_nil(properties_selection.property)
    assert_equal('feature', properties_selection.property.name)
    assert_equal(AggregateType::COUNT, properties_selection.aggregate.aggregate_type)
    assert_equal(nil, properties_selection.aggregate.property_definition)
  end

  def test_from_should_raise_exception_when_aggregate_not_supported
    data_query = CardQuery.parse('SELECT Feature, Max(Size)')
    assert_raise_with_message(InvalidPropertySelectionException, 'unsupported aggregate: MAX') do
      PropertySelection.from(data_query, [AggregateType::COUNT])
    end
  end

  def test_from_should_raise_exception_if_properties_selected_is_not_2
    data_query = CardQuery.parse('SELECT Feature, Size, Max(Size)')
    assert_raise_with_message(InvalidPropertySelectionException, 'Incorrect number of selected properties, must be only one property and aggregate') do
      PropertySelection.from(data_query, [AggregateType::COUNT])
    end
  end

  def test_from_should_raise_exception_if_first_property_is_not_property_definition
    data_query = CardQuery.parse('SELECT number, Count(*)')
    assert_raise_with_message(InvalidPropertySelectionException, 'property Number is not supported') do
      PropertySelection.from(data_query)
    end
  end

  def test_from_should_raise_exception_if_second_property_is_not_an_aggregate
    data_query = CardQuery.parse('SELECT Size, number')
    assert_raise_with_message(InvalidPropertySelectionException, 'second column must be an aggregate') do
      PropertySelection.from(data_query)
    end
  end

  def test_from_should_raise_exception_if_as_of_used
    data_query = CardQuery.parse('SELECT Feature, Count(*) AS OF "12 JUL 2016"')
    assert_raise_with_message(InvalidPropertySelectionException, 'AS OF not supported') do
      PropertySelection.from(data_query)
    end
  end
end
