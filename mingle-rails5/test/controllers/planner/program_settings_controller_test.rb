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
class ProgramSettingsControllerTest < ActionDispatch::IntegrationTest

  def setup
    @admin = create(:admin, login: :admin, admin: true)
    login_as_admin
    @program = create(:program)
  end

  def test_should_render_program_data
    get program_settings_path(@program.identifier)

    assert_response :success
    actual_program = JSON.parse(data(@response.body, 'program'))

    assert_equal({'name' => @program.name, 'id' => @program.id, 'identifier' => @program.identifier}, actual_program)
  end

  def test_should_render_program_types_with_property_definitions
    first_objective_type = @program.default_objective_type
    second_objective_type = @program.objective_types.create!(name: 'Second')

    get program_settings_path(@program.identifier)

    assert_response :success
    actual_objective_types = JSON.parse(data(@response.body, 'objective-types'))
    assert_equal 2, actual_objective_types.size

    expected_objective_types = [
        {'name' => first_objective_type.name, 'id' => first_objective_type.id, 'value_statement' => first_objective_type.value_statement,
         'property_definitions' => [
             {'id'=>first_objective_type.objective_property_definitions.first.id, 'name'=>'Size', 'program_id'=>@program.id, 'type'=>'ManagedNumber', 'managed'=>true, 'numeric'=>true, 'description' => nil},
             {'id'=>first_objective_type.objective_property_definitions.second.id, 'name'=>'Value', 'program_id'=>@program.id, 'type'=>'ManagedNumber', 'managed'=>true, 'numeric'=>true, 'description' => nil }
         ]
        },
        {'name' => second_objective_type.name, 'id' => second_objective_type.id, 'value_statement' => second_objective_type.value_statement,
         'property_definitions' => []
        }
    ]
    assert_same_elements expected_objective_types, actual_objective_types
  end

  private

  def data(response_body, data_key)
    parsed_html = Nokogiri.parse(response_body)
    main_content_tag = parsed_html.xpath("//div[@id='program_settings']")
    main_content_tag.attr("data-#{data_key}").value
  end
end
