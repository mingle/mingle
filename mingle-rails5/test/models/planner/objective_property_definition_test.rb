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

class ObjectivePropertyDefinitionTest < ActiveSupport::TestCase
  context :associations do
    should belong_to(:program)
    should validate_uniqueness_of(:name)
               .scoped_to(:program_id)
               .case_insensitive.with_message('already used for an existing property in your Program.')
    should have_many(:objective_property_mappings)
               .with_foreign_key(:obj_prop_def_id)
               .dependent(:destroy)
    should have_many(:objective_property_values)
               .with_foreign_key(:obj_prop_def_id)
               .dependent(:destroy)
  end

  def setup
    @program = create(:program)
  end

  def test_to_params_should_return_values_as_hash
    obj_prop_def = create(:objective_property_definition, program_id: @program.id)
    expected = {id: obj_prop_def.id, name: obj_prop_def.name, type: nil, managed: false, numeric: false, program_id: @program.id, description: obj_prop_def.description}
    actual = obj_prop_def.to_params.except(:created_at, :updated_at)

    assert_equal(expected, actual)
  end
end
