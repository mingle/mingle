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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class ManagedNumberTest < ActiveSupport::TestCase

  def test_should_be_of_objective_property_definition_type
    assert ManagedNumber.new.is_a?(ObjectivePropertyDefinition)
  end

  def test_should_be_managed_type
    assert ManagedNumber.new.managed?
  end

  def test_should_be_numeric_type
    assert ManagedNumber.new.numeric?
  end

  def test_to_params_should_return_values_as_hash
    program = create(:program)
    obj_prop_def = create(:managed_number_property_definition, program_id: program.id)
    expected = {id: obj_prop_def.id, name: obj_prop_def.name, type: 'ManagedNumber', managed: true, numeric: true, program_id: program.id, description: 'Default description'}
    actual = obj_prop_def.to_params.except(:created_at, :updated_at)

    assert_equal(expected, actual)
  end

  def test_parse_should_parse_value
    obj_prop_def = build(:managed_number_property_definition)
    assert_equal 45610 , obj_prop_def.parse("45610")
    assert_equal 10.44 , obj_prop_def.parse("10.44")
  end

  def test_should_return_all_existing_values_as_allowed_values
    program = create(:program)
    obj_prop_def = create(:managed_number_property_definition, program_id: program.id)
    5.times do |value|
      create(:objective_property_value, obj_prop_def_id:obj_prop_def.id, value:value)
    end

    assert_equal [ 0,1,2,3,4], obj_prop_def.allowed_values
  end
end
