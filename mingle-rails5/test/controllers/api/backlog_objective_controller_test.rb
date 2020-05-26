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
class BacklogObjectivesControllerTest < ActionDispatch::IntegrationTest

  def setup
    create(:admin, login: :admin, admin: true)
    login_as_admin
    @program = create(:program)
  end

  def test_deleting_objective_in_backlog_via_json_api
    backlog_objective = create(:objective, :backlog, name: 'test', program_id:@program.id)
    delete api_program_backlog_objective_path(@program.identifier, backlog_objective.number)
    assert_response :success
    assert_empty @response.body
    assert_equal 0, @program.reload.objectives.backlog.size
  end

  def test_not_found_error_deleting_invalid_objective_in_backlog_via_json_api
    delete api_program_backlog_objective_path(@program.identifier, 33333333)
    assert_response :not_found
    assert_empty @response.body
  end

  def test_get_backlog_objective_via_json_api
    objective = create(:objective, :backlog, name: 'test', program_id:@program.id)
    allowed_values = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    property_definitions =  {
        Size: {name:  'Size', value: 0,allowed_values: allowed_values},
        Value: {name:  'Value', value:0, allowed_values: allowed_values}
    }
    objective.create_property_value_mappings(property_definitions)
    get api_program_backlog_objective_path(@program.identifier, objective.number)
    assert_response :success
    expected_objective = {
        'name'=>'test', 'value_statement'=>nil, 'number'=>1, 'position'=>1, 'status'=>'BACKLOG',
        'property_definitions' => default_property_definitions({size:0, value:0})
    }
    assert_equal expected_objective, JSON.load(@response.body)
  end

  def test_get_planned_objective_via_json_api
    objective = create(:objective, :planned, name: 'planned_objective', program_id:@program.id)
    get api_program_backlog_objective_path(@program.identifier, objective.number)
    assert_response :success
    expected_objective = {
        'name' => 'planned_objective', 'value_statement' => nil, 'number' => 1, 'position' => 1, 'status' => 'PLANNED',
        'property_definitions' => default_property_definitions({})
    }
    assert_equal expected_objective, JSON.load(@response.body)
  end

  def test_error_on_deleting_objective_in_backlog_via_json_api
    backlog_objective = create(:objective, :backlog, name: 'test', program_id:@program.id)
    expected_errors = ['first error', 'second error']
    Objective.any_instance.stubs(:destroy).returns(false)
    Objective.any_instance.stubs(:errors).returns(expected_errors)

    delete api_program_backlog_objective_path(@program.identifier, backlog_objective.number)

    assert_response :unprocessable_entity
    assert_equal expected_errors, JSON.parse(@response.body)
  end

  def test_should_update_backlog_objective_with_property_definitions
    backlog_objective = create(:objective, :backlog, name: 'test', program_id:@program.id)
    put api_program_backlog_objective_path(@program.identifier, backlog_objective.number, backlog_objective: {name: 'test123', property_definitions:{Size:{name:'Size', value:20}}})

    actual_data =  JSON.parse(@response.body)
    expected_data = {
        'name' => 'test123',
        'property_definitions' => default_property_definitions({size:20})
    }.merge(backlog_objective.attributes.slice('number','value_statement', 'status', 'position'))
    assert_response :success
    assert_equal expected_data, actual_data
  end

  def test_update_value_statement_responds_with_html_escaped_value_statement
    backlog_objective = create(:objective, :backlog, name: 'test', program_id:@program.id)

    put api_program_backlog_objective_path(@program.identifier, backlog_objective.number, backlog_objective: {value_statement: '<h1>Tenacious D</h1>'})

    assert_equal '<h1>Tenacious D</h1>', backlog_objective.reload.value_statement
  end

  def test_reorder_objectives
    first_objective  = create(:objective, :backlog, name: 'first', program_id: @program.id)
    second_objective   = create(:objective, :backlog, name: 'second', program_id: @program.id)
    create(:objective, :planned, name: 'planned_objective', program_id: @program.id)
    assert_equal %w(second first), @program.objectives.backlog.map(&:name)
    post reorder_api_program_backlog_objectives_path(@program.identifier, ordered_backlog_objective_numbers: [first_objective.number, second_objective.number])

    expected_ordered_objective = [
        {'name' =>'first','number' => 1, 'position' => 1, 'status' => 'BACKLOG'},
        {'name' =>'planned_objective','number' => 3, 'position' => 1, 'status' => 'PLANNED'},
        {'name' =>'second','number' => 2, 'position' => 2, 'status' => 'BACKLOG'}
    ]
    ordered_objective = JSON.load @response.body
    assert_equal expected_ordered_objective, ordered_objective
  end

  def test_updating_duplicate_name_throws_error
    assert @program.objectives.backlog.create(name: 'first')
    assert @program.objectives.backlog.create(name: 'second')
    first_objective = @program.objectives.backlog.find_by_name('first')

    put api_program_backlog_objective_path(@program.identifier, first_objective.number, backlog_objective: {name: 'second'})
    assert_equal 'Name already used for an existing Objective in your Program.', @response.body
  end

  def test_removes_carriage_return_character_from_value_statement_on_save
    first_objective = @program.objectives.backlog.create(:name => 'first')
    put api_program_backlog_objective_path(@program.identifier, first_objective.number, backlog_objective: {value_statement: "s\r\n  *a\r\n  *b"})

    assert_equal "<p>s</p></br><p>&nbsp;&nbsp;*a</p></br><p>&nbsp;&nbsp;*b</p>", first_objective.reload.value_statement

    put api_program_backlog_objective_path(@program.identifier, first_objective.number, backlog_objective: {value_statement: ('s' * 749) + "\r\n"})

    assert_response :success
    assert_equal "<p>#{'s'*749}</p>", first_objective.reload.value_statement
  end

  def test_should_plan_backlog_objective
    backlog_objective = create(:objective, :backlog, name: 'test', program_id:@program.id)
    post plan_api_program_backlog_objective_path(@program.identifier, backlog_objective.number)

    assert_response :success
    assert_equal "{\"redirect_url\":\"/programs/#{@program.identifier}/plan?planned_objective=test\"}", @response.body
  end

  def test_should_return_error_backlog_objective_to_be_planned_is_not_present
    post plan_api_program_backlog_objective_path(@program.identifier, 4000)

    assert_response :not_found
  end

  def test_should_redirect_to_plan
    backlog_objective = create(:objective, :planned, name: 'test', program_id:@program.id)
    post change_plan_api_program_backlog_objective_path(@program.identifier, backlog_objective.number)

    assert_response :success
    assert_equal "{\"redirect_url\":\"/programs/#{@program.identifier}/plan?planned_objective=test\"}", @response.body
  end

  def test_should_return_error_planned_objective_to_be_re_planned_is_not_present
    post change_plan_api_program_backlog_objective_path(@program.identifier, 4000)

    assert_response :not_found
  end

  def test_should_get_backlog_objective_data
    backlog_objective = create(:objective, :backlog, program: @program)
    get api_program_backlog_objective_path(backlog_objective.program.identifier, backlog_objective.number)

    expected = {
        'name' => backlog_objective.name, 'value_statement' => nil, 'number' => 1, 'position' => 1, 'status' => 'BACKLOG',
        'property_definitions' => default_property_definitions({})
    }
    actual = JSON.parse(@response.body)
    assert_equal(expected, actual)
  end

  def test_not_found_error_when_fetching_an_invalid_objective
    get api_program_backlog_objective_path(@program.identifier, 12345)

    assert_response :not_found
    assert_empty @response.body
  end

  def test_should_create_objective_on_backlog

    post api_program_backlog_objectives_path(@program.identifier, backlog_objective: {name: 'Objective name', value_statement:'value_statement' , value:0, size:0})
    assert_response :success
    assert_equal 1, @program.objectives.backlog.size
    assert_equal 'Objective name', @program.objectives.backlog.first.name
  end

  def test_should_create_objective_on_backlog_with_property_definitions

    post api_program_backlog_objectives_path(@program.identifier, backlog_objective: {name: 'Objective name', value_statement:'value_statement' , property_definitions:{Value:{name:'Value',value:30}, Size:{name:'Size',value:40}}})
    assert_response :success
    assert_equal 1, @program.objectives.backlog.size
    expected_objective = {
        'name'=>'Objective name', 'value_statement'=>'value_statement', 'number'=>1, 'position'=>1, 'status'=>'BACKLOG',
        'property_definitions' => default_property_definitions({size:40, value:30})
    }
    assert_equal expected_objective, JSON.load(@response.body)
  end

  def test_should_render_error_for_duplicate_objective_name
    program = create(:simple_program)
    create(:objective, :backlog, name: "Duplicate name", program_id: program.id )

    post api_program_backlog_objectives_path(program.identifier, backlog_objective: {name: 'Duplicate name', value_statement:'value_statement' , value:0, size:0})

    assert_equal "Name already used for an existing Objective in your Program.", @response.body
  end

  def test_should_not_allow_to_create_objective_when_readonly_mode_is_toggled_on
    program = create(:simple_program)
    MingleConfiguration.overridden_to(readonly_mode: true) do
      post api_program_backlog_objectives_path(program.identifier, backlog_objective: {name: 'Duplicate name', value_statement:'value_statement' , value:0, size:0})
        assert_response :redirect
    end
  end

  def test_should_not_allow_to_destroy_objective_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
        program = create(:simple_program)
        backlog_objective = create(:objective, :backlog, name: 'test', program_id:program.id)
        delete api_program_backlog_objective_path(program.identifier, backlog_objective.number)
        assert_response :redirect
    end
  end

  def test_should_not_allow_to_update_objective_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
        program = create(:simple_program)
        assert program.objectives.backlog.create(name: 'first')
        first_objective = program.objectives.backlog.find_by_name('first')

        put api_program_backlog_objective_path(program.identifier, first_objective.number, backlog_objective: {name: 'second'})
        assert_response :redirect
    end
  end

  private
  def default_property_definitions(selected_values)
    allowed_values = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    {
        'Size' => {'name' => 'Size', 'value' => selected_values[:size] || '(not set)', 'allowed_values' => allowed_values},
        'Value' => {'name' => 'Value', 'value' => selected_values[:value] || '(not set)', 'allowed_values' => allowed_values}
    }
  end

end
