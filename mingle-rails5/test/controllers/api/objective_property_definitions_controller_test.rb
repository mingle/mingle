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
class ObjectivePropertyDefinitionsControllerTest < ActionDispatch::IntegrationTest

  def setup
    create(:admin, login: :admin, admin: true)
    login_as_admin
    @program = create(:program)
  end

  def test_should_create_property_definition
    post api_program_objective_property_definitions_path(@program.identifier, property: {name: 'Status', description: 'tells you the status', type: 'ManagedNumber'})
    status = @program.objective_property_definitions.find_by_name('Status')

    assert_response :success
    assert_equal 3, @program.objective_property_definitions.size
    assert_equal   'tells you the status', status.description
    assert_equal   'ManagedNumber', status.type
  end

  def test_should_show_error_message_on_creating_same_property
    post api_program_objective_property_definitions_path(@program.identifier, property: {name: 'Size', description: 'tells you the status', type: 'ManagedNumber'})

    assert_response :unprocessable_entity
    assert_equal 'Name already used for an existing property in your Program.', @response.body
    assert_equal 2, @program.objective_property_definitions.size
  end
end
