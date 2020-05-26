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

require File.expand_path('../../../test_helper', __FILE__)
class ObjectiveTypesControllerTest < ActionDispatch::IntegrationTest

  def setup
    create(:admin, login: :admin, admin: true)
    login_as_admin
    @program = create(:program)
  end

  def test_update_should_return_not_found_if_objective_type_does_no_exist
    put api_program_objective_type_path(@program.identifier, 99999999)

    assert_response :not_found
  end

  def test_update_should_return_updated_objective_type
    default_objective_type = @program.default_objective_type
    put api_program_objective_type_path(@program.identifier, default_objective_type.id, objective_type: {name: 'NewName', value_statement: 'new value statement'})

    assert_response :success
    assert_equal({'id' => default_objective_type.id, 'name' => 'NewName', 'value_statement' => 'new value statement'}, JSON.parse(@response.body))
  end

end
