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
class UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create(:admin, login: :admin, admin: true)
    login_as_admin
  end

  def test_should_retrieve_all_activated_users
    program = create(:program)
    user1 = create(:user, name: 'user 1')
    user2 = create(:user, name: 'user 2')
    user3 = create(:light_user, name: 'light_user2')
    user4 = create(:user, name: 'deactivated', activated: false)
    program.add_member(user1)
    get api_users_path(program.identifier)

    expected_response = [{'id' => @admin.id, 'name' => @admin.name, 'login' => @admin.login, 'email' => @admin.email,   'light' => false},
                         {'id' => user1.id, 'name' => user1.name, 'login' => user1.login, 'email' => user1.email,   'light' => false},
                         {'id' => user2.id, 'name' => user2.name, 'login' => user2.login, 'email' => user2.email,   'light' => false},
                         {'id' => user3.id, 'name' => user3.name, 'login' => user3.login, 'email' => user3.email,   'light' => true}]

    assert_response :success
    assert_same_elements expected_response, JSON.parse(@response.body)

  end

  def test_should_not_fetch_light_users_if_exclude_light_users_is_true
    program = create(:program)
    user1 = create(:user, name: 'user 1')
    user2 = create(:user, name: 'user 2')
    user3 = create(:light_user, name: 'light_user2')
    program.add_member(user1)
    get api_users_path(program.identifier), params: {exclude_light_users: true}

    expected_response = [{'id' => @admin.id, 'name' => @admin.name, 'login' => @admin.login, 'email' => @admin.email,   'light' => false},
                         {'id' => user2.id, 'name' => user2.name, 'login' => user2.login, 'email' => user2.email,   'light' => false},
                         {'id' => user1.id, 'name' => user1.name, 'login' => user1.login, 'email' => user1.email,   'light' => false}]

    assert_response :success
    assert_same_elements expected_response, JSON.parse(@response.body)
  end

  def test_should_retrieve_all_projects_for_a_user
    project1 = create(:project, created_by_user_id: @admin.id)
    project2 = create(:project, created_by_user_id: @admin.id)
    project3 = create(:project, created_by_user_id: @admin.id)
    project4 = create(:project, created_by_user_id: @admin.id)
    expected_result = {"userLogin"=>"admin", "projects"=> [project1.name, project2.name, project3.name, project4.name]}
    get api_user_projects_path(@admin.login), params: {user_login: @admin.login}

    assert_response :success
    actual = JSON.parse(@response.body)

    assert_equal expected_result['userLogin'], actual['userLogin']
    assert_same_elements expected_result['projects'], actual['projects']
  end

  def test_should_retrieve_only_the_projects_for_a_user_that_belong_to_the_program
    project1 = create(:project, created_by_user_id: @admin.id)
    project2 = create(:project, created_by_user_id: @admin.id)
    project3 = create(:project, created_by_user_id: @admin.id)
    project4 = create(:project, created_by_user_id: @admin.id)
    program = create(:program)
    create(:program_project, project_id: project1.id, program_id: program.id)
    create(:program_project, project_id: project2.id, program_id: program.id)
    expected_result = {"userLogin"=>"admin", "projects"=> [project1.name, project2.name]}
    get api_user_projects_path(@admin.login), params: {user_login: @admin.login, program_id: program.identifier}

    assert_response :success
    actual = JSON.parse(@response.body)

    assert_equal expected_result['userLogin'], actual['userLogin']
    assert_same_elements expected_result['projects'], actual['projects']
  end
end
