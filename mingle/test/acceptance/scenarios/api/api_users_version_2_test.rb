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

require File.expand_path(File.dirname(__FILE__) + '/api_test_helper')

# Tags: api_version_2
class ApiUsersVersion2Test < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :users => [User.find_by_login('member')], :read_only_users => [User.find_by_login('read_only_user')], :admins => [User.find_by_login('proj_admin')]) { |project| create_cards(project, 3) }
      @deactivated_user = User.create!(:name => 'deactivated_user', :login => 'deactivated_user', :email => 'deactivated_user@email.com', :password => 'pass1.', :password_confirmation => 'pass1.', :activated => false)
    end
    API::User.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::User.prefix = "/api/#{version}/"
  end

  def teardown
    disable_basic_auth
  end

  def test_should_return_401_when_login_failed
    API::User.site = "http://admin:notpassword@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::User.prefix = "/projects/#{@project.identifier}/"
    assert_unauthorized do
      API::User.find(:all)
    end
  end

  def test_should_return_404_when_login_with_deactivated_user
    API::User.site = "http://deactivated_user:pass1.@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::User.prefix = "/projects/#{@project.identifier}/"
    e = assert_not_found { API::User.find(:all) }
    assert_equal '404', e.response.code
  end

  def test_get_team_members_by_admin
    API::User.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    API::User.prefix = "/api/#{version}/projects/#{@project.identifier}/"
    API::Project.prefix = "/api/#{version}/projects/#{@project.identifier}/"
    API::Project.site = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"

    team = API::User.find(:all)
    users = team.collect(&:user)
    assert_equal @project.reload.users.collect(&:name).sort, users.collect(&:name).sort
    assert users.first.respond_to?(:version_control_user_name)
    assert users.first.respond_to?(:activated)
    assert users.first.respond_to?(:admin)
  end

  def test_should_get_project_membership_level_information_for_team
    API::User.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    API::User.prefix = "/api/#{version}/projects/#{@project.identifier}/"
    API::Project.prefix = "/api/#{version}/projects/#{@project.identifier}/"
    API::Project.site = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"

    team = API::User.find(:all)
    assert_equal ['member', 'proj_admin', 'read_only_user'], team.collect(&:user).collect(&:login).sort

    non_admin_team_members = team.select { |t| t.user.login == 'member' || t.user.login == 'read_only_user' }
    assert non_admin_team_members.all? { |member| !member.admin? }

    read_only_user = team.detect { |t| t.user.login == 'read_only_user' }
    assert read_only_user.readonly_member
  end

  def test_should_only_have_user_name_login_and_email_info_when_a_team_member_use_the_get_team_members_api
    API::User.prefix = "/api/#{version}/projects/#{@project.identifier}/"
    API::User.site = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    API::Project.prefix = "/api/#{version}/projects/#{@project.identifier}/"
    API::Project.site = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    team = API::User.find(:all)
    users = team.collect(&:user)
    assert_equal @project.reload.users.collect(&:name).sort, users.collect(&:name).sort
    assert !users.first.respond_to?("version_control_user_name")
    assert !users.first.respond_to?(:activated)
    assert !users.first.respond_to?(:admin)
  end

  def test_get_all_users
    users = API::User.find(:all)
    assert_equal ::User.find_all_in_order.collect(&:name), users.collect(&:name)
  end

  def test_create_admin_user
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :admin => 'true')
    user.reload
    assert 'blabla_new_user', user.login
    assert user.admin?
    assert !user.light?
    assert user.errors.empty?
  end

  def test_create_light_user
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :light => 'true')
    user.reload
    assert user.errors.empty?
    assert user.light?
    assert !user.admin?
  end

  def test_create_user_who_is_neither_admin_nor_light
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')
    user.reload
    assert user.errors.empty?
    assert !user.light?
    assert !user.admin?
  end

  def test_should_not_allow_to_create_user_when_the_max_full_and_light_activated_users_reached
    register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users)

    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')

    assert User.find_by_login(user.login).nil?
    assert !user.errors.empty?
  end

  def test_should_allow_to_create_light_user_when_the_max_light_activated_users_reached_and_max_active_full_users_not_reached
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)

    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :light => true)

    assert user.errors.empty?
  end

  def test_should_not_allow_creation_of_full_user_when_the_max_full_activated_users_reached
    register_license(:max_active_users => User.activated_full_users)

    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')

    assert User.find_by_login(user.login).nil?
    assert !user.errors.empty?

    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :light => true)
    assert User.find_by_login(user.login)
    assert user.errors.empty?
  end

  def test_should_not_allow_make_user_from_light_to_full_when_the_max_full_activated_users_reached
    register_license(:max_active_users => User.activated_full_users)

    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :light => true)
    user.light = false
    assert_false user.save
    assert_false user.errors.empty?
  end

  def test_should_be_able_to_create_deactived_user_when_the_max_users_reached
    register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users)
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :activated => false)
    assert user.errors.empty?
  end

  def test_should_not_be_able_to_get_user_password
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :admin => 'true')
    user = API::User.find(user.id)
    assert !user.respond_to?(:password)
    assert_not_nil User.find_by_login("blabla_new_user").password
  end

  def test_should_get_if_user_is_a_light_user
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :light => true)

    user = API::User.find(user.id)
    assert user.light?
  end

  def test_should_not_be_able_to_update_user_as_admin
    member_id = User.find_by_login('member').id
    params = {'user[admin]' => 'true'}
    response = put("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/users/#{member_id}.xml", params)
    assert_equal "403", response.code.to_s
    assert_include "Either the resource you requested does not exist or you do not have access rights to that resource.", response.body
  end

  def test_should_not_be_able_to_create_user_by_member
    API::User.site = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::User.prefix = "/api/#{version}/"

    assert_forbidden do
      API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')
    end
  end

  def test_create_user_failed
    user = API::User.create(:email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')
    assert !user.errors.empty?
  end

  def test_find_user_by_invalid_id
    assert_not_found { API::User.find(404) }
  end

  def test_update_user
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')
    user.reload
    old_password = User.find_by_login(user.login).password
    assert !user.admin?
    assert user.activated?
    user.name = "new name"
    user.admin = true
    user.activated = false
    user.password = "new password1."
    user.password_confirmation = "new password1."
    assert user.save

    user = API::User.find(user.id)
    assert 'new name', user.name
    assert user.admin?
    assert !user.light?
    assert !user.activated?
    assert user.errors.empty?
    assert !user.attributes.include?(:salt)
    assert_not_equal old_password, User.find_by_login(user.login).password
  end

  def test_should_allow_update_light_property_through_api
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')
    assert !user.light?

    user.light = true
    user.save
    assert user.light?
  end

  def test_should_update_light_property_when_this_user_is_admin
    admin = API::User.create(:login => 'blabla_new_user',
                             :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.', :admin => true)
    assert admin.admin?

    admin.admin = false
    admin.light = true
    admin.save

    assert !admin.reload.admin?
    assert admin.light?
  end

  def test_should_not_allow_admin_user_set_himself_to_light_user
    current_admin = API::User.find(User.find_by_login('admin').id)
    assert current_admin.admin?

    current_admin.light = true

    current_admin.save

    assert !current_admin.errors.empty?
    assert_equal 'You cannot update your own user permission attributes.', current_admin.errors.on_base
  end

  def test_find_user_by_id
    member = User.find_by_login("member")

    user = API::User.find(member.id)
    assert_equal member.login, user.login
    assert user.errors.empty?
  end

  def test_update_user_failed
    user = API::User.create(:login => 'blabla_new_user', :email => "blabla_new_user@email.com", :name => "user name", :password => 'pass1.', :password_confirmation => 'pass1.')
    user.name = ""
    assert !user.save

    assert 'new name', user.name
    assert !user.errors.empty?
  end

  def test_should_contains_user_icon
    user = create_user!(:icon => sample_attachment('icon.png'))
    api_user = API::User.find(user.id)
    assert_equal "/user/icon/#{user.id}/icon.png", api_user.icon_path
  end

  # Bug 7721
  def test_get_team_members_when_none_exist_should_get_users_as_root_element
    response = get("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/users.xml", {})
    assert_equal 1, get_number_of_elements(response.body, "/projects_members")
  end

  def version
    "v2"
  end

  def test_users_should_include_link_to_project_resource_through_project_member
    url = URI.parse("#{API::User.site}/projects/#{@project.identifier}/users.xml")
    response = get(url, {})
    document = REXML::Document.new(response.read_body)

    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}.xml", document.attribute_value_at("/projects_members/projects_member[user/login='member']/project/@url")
  end

  def test_project_should_include_link_to_user_resource
    url = URI.parse("#{API::User.site}/projects/#{@project.identifier}/users.xml")
    response = get(url, {})
    document = REXML::Document.new(response.read_body)
    member = User.find_by_login('member')
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/users/#{member.id}.xml", document.attribute_value_at("/projects_members/projects_member/user[login='member']/@url")
  end

end
