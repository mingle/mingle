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
class ProgramMembershipsControllerTest < ActionDispatch::IntegrationTest

  def setup
    @admin = create(:admin, login: :admin, admin: true)
    login_as_admin
    @program = create(:program)
  end

  def test_remove_multiple_member
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    @program.add_member(user1)
    @program.add_member(user2)
    @program.add_member(user3)

    post bulk_remove_api_program_program_memberships_path(@program.identifier, members_login: [user1.login, user2.login])
    assert_response :success
    assert_equal '2 members have been removed from this program.', @response.body
    assert_false @program.member?(user1)
    assert_false @program.member?(user2)
    assert @program.member?(user3)
  end

  def test_remove_single_member
    user = create(:user)
    @program.add_member(user)

    post bulk_remove_api_program_program_memberships_path(@program.identifier, members_login: [user.login])
    assert_response :success
    assert_equal "#{user.name} has been removed from this program.", @response.body
    assert_false @program.member?(user)
  end

  def test_member_can_not_remove_himself
    user = create(:user)
    @program.add_member(user, :program_admin)
    login(user)

    post bulk_remove_api_program_program_memberships_path(@program.identifier, members_login: [user.login])

    assert_response :unprocessable_entity
    assert_equal 'Cannot remove yourself from program.', @response.body
    assert @program.member?(user)
  end

  def test_should_return_the_newly_added_member_data
    user1 = create(:user, name: 'user 1', login: 'user_1')
    post api_program_program_memberships_path(@program.identifier), params: {user_login: user1.login, role: :program_admin}
    assert_response :ok

    expected_member_data= {'id'=>user1.id, 'name'=>'user 1', 'login'=>'user_1', 'email'=>'user_1@email.com', 'role'=> {'name'=>'Program administrator', 'id'=>'program_admin'}, 'is_team_member'=>true, 'light_user'=>false, 'projects'=>'', 'activated'=>true}
    assert_equal expected_member_data, JSON.load(@response.body)
  end

  def test_should_add_user_as_program_admin
    user1 = create(:user, name: 'user 1', login: 'user_1')
    post api_program_program_memberships_path(@program.identifier), params: {user_login: user1.login, role: :program_admin}
    assert_response :ok

    user1_member_role = @program.member_roles.find_by_member_id(user1.id)
    assert_equal 'program_admin', user1_member_role.permission
  end


  def test_should_add_user_as_program_member
    user1 = create(:user, name: 'user 1', login: 'user_1')
    post api_program_program_memberships_path(@program.identifier), params: {user_login: user1.login, role: :program_member}
    assert_response :ok

    user1_member_role = @program.member_roles.find_by_member_id(user1.id)
    assert_equal 'program_member', user1_member_role.permission
  end


  def test_should_return_error_for_adding_team_member_with_incorrect_role
    user1 = create(:user, name: 'user 1', login: 'user_1')
    post api_program_program_memberships_path(@program.identifier), params: {user_login: user1.login, role: :member}

    assert_response :unprocessable_entity
    assert_equal 'Cannot add user:Invalid role', @response.body
  end

  def test_should_return_the_projects_for_the_member
    user1 = create(:user, name: 'user 1', login: 'user_1')
    project1 = create(:project, created_by_user_id: user1.id)
    project2 = create(:project, created_by_user_id: user1.id)
    create(:program_project, project_id: project1.id, program_id: @program.id)

    post api_program_program_memberships_path(@program.identifier), params: {user_login: user1.login, role: :program_member}
    assert_response :ok

    actual = JSON.parse(@response.body)
    assert actual['projects'].include? project1.name
    assert_false actual['projects'].include? project2.name
  end


  def test_should_bulk_update_members_role
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    user4 = create(:user)
    user5 = create(:user)
    @program.add_member(user1, :program_admin)
    @program.add_member(user2, :program_admin)
    @program.add_member(user3, :program_admin)
    @program.add_member(user4, :program_admin)
    @program.add_member(user5, :program_admin)

    post bulk_update_api_program_program_memberships_path(@program.identifier, members_login: [user1.login, user3.login, user5.login], role: 'program_member')

    assert_response :ok
    assert_equal '3 members role have been updated to Program member.', JSON.parse(@response.body)['message']

    assert_equal 'program_member', @program.member_roles.find_by_member_id(user1.id).permission
    assert_equal 'program_admin', @program.member_roles.find_by_member_id(user2.id).permission
    assert_equal 'program_member', @program.member_roles.find_by_member_id(user3.id).permission
    assert_equal 'program_admin', @program.member_roles.find_by_member_id(user4.id).permission
    assert_equal 'program_member', @program.member_roles.find_by_member_id(user5.id).permission
  end

  def test_bulk_update_should_update_member_role
    user1 = create(:user)
    @program.add_member(user1, :program_admin)

    post bulk_update_api_program_program_memberships_path(@program.identifier, members_login: [user1.login], role: 'program_member')

    assert_response :ok
    assert_equal "#{user1.name} role has been updated to Program member.", JSON.parse(@response.body)['message']

    assert_equal 'program_member', @program.member_roles.find_by_member_id(user1.id).permission
  end

  def test_non_program_admin_should_not_have_access_to_bulk_update
    user1 = create(:user)
    @program.add_member(user1, :program_member)
    login(user1)
    post bulk_update_api_program_program_memberships_path(@program.identifier, members_login: [user1.login], role: 'program_member')

    assert_response :redirect
  end

  def test_program_admin_should_have_access_to_bulk_update
    user1 = create(:user)
    @program.add_member(user1, :program_admin)
    login(user1)
    post bulk_update_api_program_program_memberships_path(@program.identifier, members_login: [user1.login], role: 'program_member')

    assert_response :ok
  end


  def test_bulk_update_should_not_change_member_role
    user1 = create(:user)

    post bulk_update_api_program_program_memberships_path(@program.identifier, members_login: [user1.login], role: 'program_member')

    assert_response :unprocessable_entity
  end
end
