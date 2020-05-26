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

  def test_should_render_all_user_data
    user1 = create(:user, name: 'user 1')
    user2 = create(:user, name: 'user 2')
    user3 = create(:user, name: 'user 3', activated: false)
    project1 = create(:project)
    project1.add_member(user1)
    @program.add_member(user1)
    @program.add_member(user2)
    @program.add_member(user3, :program_admin)
    create(:program_project, project_id: project1.id,program_id:@program.id)


    get program_memberships_path(@program.identifier)

    assert_response :success

    users_data = JSON.parse(data(@response.body, 'members'))

    users_data = users_data.sort_by {|obj| obj['name']}
    assert_equal(4, users_data.count)

    assert_equal({'name' => @admin.name, 'login' => @admin.login, 'email' => @admin.email, "role"=>{"name"=>"Program administrator", "id"=>"program_admin"}, 'activated' => true, 'projects' => ""}, users_data.first)
    assert_equal({'name' => user1.name, 'login' => user1.login, 'email' => user1.email, "role"=>{"name"=>"Program member", "id"=>"program_member"}, 'activated' => true, 'projects' => "#{project1.name}"}, users_data.second)
    assert_equal({'name' => user2.name, 'login' => user2.login, 'email' => user2.email, "role"=>{"name"=>"Program member", "id"=>"program_member"}, 'activated' => true, 'projects' => ""}, users_data.third)
    assert_equal({'name' => user3.name, 'login' => user3.login, 'email' => user3.email, "role"=>{"name"=>"Program administrator", "id"=>"program_admin"}, 'activated' => false, 'projects' => ""}, users_data.fourth)
  end

  def test_should_fetch_only_the_user_projects_which_are_associated_with_a_specific_program
    user1 = create(:user, name: 'user 1')
    project1 = create(:project, created_by_user_id: user1.id)
    project2 = create(:project, created_by_user_id: user1.id)
    project3 = create(:project, created_by_user_id: user1.id)

    @program.add_member(user1)
    create(:program_project, project_id: project1.id, program_id: @program.id)

    get program_memberships_path(@program.identifier)

    assert_response :success

    users_data = JSON.parse(data(@response.body, 'members'))

    users_data = users_data.sort_by {|obj| obj['name']}
    assert_equal(2, users_data.count)

    assert_equal({'name' => @admin.name, 'login' => @admin.login, 'email' => @admin.email, "role"=>{"name"=>"Program administrator", "id"=>"program_admin"}, 'activated' => true, 'projects' => ""}, users_data.first)
    assert_equal({'name' => user1.name, 'login' => user1.login, 'email' => user1.email, 'role' => {"name"=>"Program member", "id"=>"program_member"}, 'activated' => true, 'projects' => "#{project1.name}"}, users_data.second)
  end

  def test_should_set_current_user
    user1 = create(:user, name: 'user 1')
    user2 = create(:user, name: 'user 2', admin:true)
    user3 = create(:user, name: 'user 3')
    @program.add_member(user1)
    @program.add_member(user2)
    @program.add_member(user3, :program_admin)

    login(user1)
    get program_memberships_path(@program.identifier)

    expected_current_user = {id:user1.id, name:user1.name, login:user1.login, admin:false, mingleAdmin:false}
    assert_equal expected_current_user, JSON.parse(data(@response.body, 'current-user')).symbolize_keys

    login(user3)

    get program_memberships_path(@program.identifier)

    expected_current_user = {id:user3.id, name:user3.name, login:user3.login, admin:true, mingleAdmin:false}
    assert_equal expected_current_user, JSON.parse(data(@response.body, 'current-user')).symbolize_keys

    login(user2)

    get program_memberships_path(@program.identifier)

    expected_current_user = {id:user2.id, name:user2.name, login:user2.login, admin:true, mingleAdmin:true}
    assert_equal expected_current_user, JSON.parse(data(@response.body, 'current-user')).symbolize_keys
  end

  def test_should_render_all_user_data_except_system_user_data
    user1 = create(:user, name: 'user 1')
    user2 = create(:user, name: 'user 2')
    user3 = create(:user, name: 'user 3')
    user2.update(system: true)
    project1 = create(:project, created_by_user_id: user1.id)
    @program.add_member(user1, :program_member)
    @program.add_member(user2)
    @program.add_member(user3, :program_admin)
    create(:program_project, project_id: project1.id,program_id:@program.id)

    login(user1)
    get program_memberships_path(@program.identifier)
    assert_response :success

    users_data = JSON.parse(data(@response.body, 'members'))

    users_data = users_data.sort_by {|obj| obj['name']}
    assert_equal(3, users_data.count)
    assert_equal({'name' => @admin.name, 'login' => @admin.login, 'email' => @admin.email, "role"=>{"name"=>"Program administrator", "id"=>"program_admin"}, 'activated' => true, 'projects' => ""}, users_data.first)
    assert_equal({'name' => user1.name, 'login' => user1.login, 'email' => user1.email, "role"=>{"name"=>"Program member", "id"=>"program_member"}, 'activated' => true, 'projects' => "#{project1.name}"}, users_data.second)
    assert_equal({'name' => user3.name, 'login' => user3.login, 'email' => user3.email, "role"=>{"name"=>"Program administrator", "id"=>"program_admin"}, 'activated' => true, 'projects' => ""}, users_data.third)
  end

  def test_should_render_program_memberships_base_path
    get program_memberships_path(@program.identifier)
    assert_response :success

    assert_equal "/api/internal/programs/#{@program.identifier}/program_memberships", data(@response.body, 'program-membership-base-url')
  end

  def test_should_not_render_program_actions_when_program_settings_are_not_enabled
    get program_memberships_path(@program.identifier)

    assert_select 'ul.program-actions #program_settings_app', count: 0
  end

  def test_should_render_roles_data
    get program_memberships_path(@program.identifier)
    assert_response :success

    assert_equal [{'id' => 'program_admin', 'name' => 'Program administrator'}, {'id' => 'program_member', 'name' => 'Program member'}], JSON.parse(data(@response.body, 'roles'))
  end


  private

  def data(response_body, data_key)
    parsed_html = Nokogiri.parse(response_body)
    main_content_tag = parsed_html.xpath("//div[@id='program_team']")
    main_content_tag.attr("data-#{data_key}").value
  end
end
