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

  def test_should_render_all_objectives_when_swim_lanes_enabled_toggle_is_on
    [{name: :first, status: 'BACKLOG'}, {name: :second, status: 'BACKLOG'}, {name: :third}].each do |objective|
      create(:objective, (objective[:status] ? :backlog : :planned), name: objective[:name], program_id: @program.id)
    end

    get program_backlog_objectives_path(@program.identifier)

    assert_response :success

    parsed_html = Nokogiri.parse(@response.body)
    main_content_tag = parsed_html.xpath("//div[@id='objectives']")
    backlog_objectives_data = JSON.parse(main_content_tag.attr('data-objectives').value)

    assert_equal(3, backlog_objectives_data.count)
    assert_equal({'position' => 1, 'name' => 'second', 'number' => 2, 'status' => 'BACKLOG'}, backlog_objectives_data.first)
    assert_equal({'position' => 1, 'name' => 'third', 'number' => 3, 'status' => 'PLANNED'}, backlog_objectives_data.second)
    assert_equal({'position' => 2, 'name' => 'first', 'number' => 1, 'status' => 'BACKLOG'}, backlog_objectives_data.third)
  end

  def test_should_render_backlog_objective_path
    create(:objective, :backlog, :name => 'first', program_id: @program.id)

    get program_backlog_objectives_path(@program.identifier)

    assert_response :success

    parsed_html = Nokogiri.parse(@response.body)
    main_content_tag = parsed_html.xpath("//div[@id='objectives']")

    expected_backlog_objective_path = "/api/internal/programs/#{@program.identifier}/backlog_objectives"
    actual_backlog_objectives_path = main_content_tag.attr('data-objectives-base-url').value

    assert_equal(expected_backlog_objective_path, actual_backlog_objectives_path)
  end

  def test_should_render_next_backlog_objective_number
    backlog_objective = create(:objective, :backlog, :name => 'first', program_id: @program.id)

    get program_backlog_objectives_path(@program.identifier)

    assert_response :success

    parsed_html = Nokogiri.parse(@response.body)
    main_content_tag = parsed_html.xpath("//div[@id='objectives']")

    actual_number = main_content_tag.attr('data-next-objective-number').value

    assert_equal(backlog_objective.number.next, actual_number.to_i)
  end

  def test_should_render_default_objective_type
    get program_backlog_objectives_path(@program.identifier)

    assert_response :success

    parsed_html = Nokogiri.parse(@response.body)
    main_content_tag = parsed_html.xpath("//div[@id='objectives']")

    actual_default_objective_type = JSON.parse(main_content_tag.attr('data-default-objective-type'))

    default_type = @program.default_objective_type
    expected_default_objective_type = {'id' => default_type.id, 'value_statement' => default_type.value_statement, 'name' => default_type.name}

    assert_equal(expected_default_objective_type, expected_default_objective_type)
  end

  def test_should_render_next_backlog_objective_number_when_no_objectives_exist
    get program_backlog_objectives_path(@program.identifier)

    assert_response :success

    parsed_html = Nokogiri.parse(@response.body)
    main_content_tag = parsed_html.xpath("//div[@id='objectives']")

    actual_number = main_content_tag.attr('data-next-objective-number').value

    assert_equal(1, actual_number.to_i)
  end

  def test_should_render_program_settings_when_program_settings_are_enabled_and_user_is_admin
    MingleConfiguration.overridden_to(program_settings_enabled: true) do
      user = create(:user)
      @program.add_member(user, :program_admin)
      login(user)

      get program_backlog_objectives_path(@program.identifier)

      assert_response :success
      assert_select '#header-pills li.program_settings', count: 1
    end
  end

  def test_should_not_render_program_settings_when_program_settings_are_enabled_and_user_is_not_Admin
    MingleConfiguration.overridden_to(program_settings_enabled: true) do
      user = create(:user)
      @program.add_member(user)
      login(user)

      get program_backlog_objectives_path(@program.identifier)

      assert_response :success
      assert_select '#header-pills li.program_settings', count: 0
    end
  end
end
