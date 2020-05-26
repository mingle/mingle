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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class Project::HasManyUserMemberTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    login_as_admin
  end
  
  def test_newly_created_project_should_have_a_team
    assert_not_nil @project.team
    assert_not_nil create_project.team
  end
  
  def test_mingle_admin_should_not_automatically_be_a_member_of_project_that_she_creates
    login_as_admin
    with_new_project do |project|
      assert_equal 0 , project.users.size
    end
  end
  
  def test_can_get_users_belonging_to_project
    another_project = project_without_cards
    assert_equal 4, @project.users.size
    assert_equal 3, project_without_cards.users.size
    another_project.add_member(User.find_by_login('longbob'))
    assert_equal 4, another_project.reload.users.size
    assert_equal 4, @project.reload.users.size
  end
  
  def test_users_belongs_to_project
    assert @project.member?(User.find_by_login('member'))
    assert !@project.member?(User.find_by_login('longbob'))
  end
  
  def test_user_should_be_uniq_in_one_project
    @user = create_user!
    with_new_project do |project|
      project.add_member(@user)
      project.add_member(@user)
      
      assert_equal [@user], project.users
    end
  end
  
  def test_should_not_add_duplicate_admin_if_it_exists
    @user = create_user!
    assert_difference("@project.reload.admins.size", +1) do
      @project.add_member(@user, :project_admin)
      @project.add_member(@user, :project_admin)
    end  
  end
  
  def test_mingle_admin_should_be_project_admin
    assert @project.admin?(User.find_by_login('admin'))
  end
  
  def test_project_admin_should_be_member
    @user = create_user!
  
    assert !@project.users.include?(@user)
    assert !@project.member?(@user)
    @project.add_member(@user, :project_admin)
    assert @project.users.include?(@user)
    assert @project.member?(@user)
  end
  
  def test_project_admin
    @user = create_user!
    assert_false @project.project_admin?(@user)
    @project.add_member(@user, :project_admin)
    @project.reload
    assert @project.admin?(@user)
    assert !@user.admin?
  end
  
  def test_all_members_should_still_be_what_role_they_are_when_license_is_invalid
    clear_license
    proj_admin = User.find_by_login('proj_admin')
    member = User.find_by_login('member')
    assert @project.admin?(proj_admin)
    assert !@project.readonly_member?(proj_admin)
    assert !@project.readonly_member?(member)
    assert @project.member?(member)
    assert @project.project_admin?(proj_admin)
  end
  
  def test_should_add_readonly_member
    user1 = User.find_by_email('member@email.com')
    assert !@project.readonly_member?(user1)

    @project.add_member(user1, :readonly_member)
    assert @project.member?(user1)
    assert @project.readonly_member?(user1)
  end  
  
  def test_user_should_be_not_readonly_project_memeber_when_user_is_not_in_project
    new_user = create_user!
    assert !@project.readonly_member?(new_user)
  end
  
  def test_anonymous_user_should_not_be_member_of_any_project
    assert !@project.member?(nil)
    assert !@project.member?(User.anonymous)
  end
  
  def test_user_are_not_in_the_project_should_have_no_role
    longbob = User.find_by_login("longbob")
    
    assert_false @project.admin?(longbob)
    assert_false @project.readonly_member?(longbob)
    assert_false @project.member?(longbob)
    assert_nil @project.role_for(longbob)
  end
  
  def test_member_should_become_readonly_member_if_he_becomes_light
    longbob = User.find_by_login("longbob")

    @project.add_member(longbob)
    longbob.update_attributes(:light => true)    
    assert @project.readonly_member?(longbob)
  end
  
  def test_light_user_should_be_readonly_member
    longbob = User.find_by_login("longbob")
    longbob.update_attributes(:light => true)

    @project.add_member(longbob)
    assert @project.readonly_member?(longbob)
  end
  
  def test_light_user_should_be_readonly_member_even_he_is_added_as_project_admin
    longbob = User.find_by_login("longbob")
    @project.add_member(longbob, :project_admin)
    longbob.update_attributes(:light => true)
    assert @project.readonly_member?(longbob)
    assert_false @project.admin?(longbob)
    assert_false @project.project_admin?(longbob)
  end
  
  def test_remove_member
    longbob = User.find_by_login("longbob")
    @project.add_member(longbob, :project_admin)
    @project.remove_member(longbob)
    
    assert_false @project.project_admin?(longbob)
    assert_false @project.member?(longbob)
    assert_false @project.readonly_member?(longbob)
  end

  def test_team_members_with_role_and_group_info_should_return_team_members
    with_new_project do |project|
      create_user!(name: 'User 1', login:'user_1')
      team_member = create_user!(name: 'Team Member', login:'team_member')
      dev = create_user!(name: 'Dev', login:'dev')
      qa = create_user!(name: 'QA', login:'qa')
      export = create_user!(name: 'Export', login:'export')
      readonly_member = create_user!(name: 'Read Only Member', login:'read_only_member')
      project_admin = create_user!(name: 'Project Admin', login:'project_admin')

      create_group('DEV\'s',[team_member, dev, export])
      create_group('QA', [qa])
      create_group('EXPORT',[export])
      project.add_member(team_member)
      project.add_member(dev)
      project.add_member(qa)
      project.add_member(export)
      project.add_member(readonly_member, MembershipRole[:readonly_member])
      project.add_member(project_admin, MembershipRole[:project_admin])
      expected = [
          {'id' => dev.id, 'Name' => 'Dev', 'Sign-in name' => 'dev', 'Email' => dev.email, 'Permissions' => 'full_member', 'User groups' => "DEV's, Team" },
          {'id' => export.id, 'Name' => 'Export', 'Sign-in name' => 'export', 'Email' => export.email, 'Permissions' => 'full_member', 'User groups' => "DEV's, EXPORT, Team" },
          {'id' => project_admin.id, 'Name' => 'Project Admin', 'Sign-in name' => 'project_admin', 'Email' => project_admin.email, 'Permissions' => 'project_admin', 'User groups' => "Team" },
          {'id' => qa.id, 'Name' => 'QA', 'Sign-in name' => 'qa', 'Email' => qa.email, 'Permissions' => 'full_member', 'User groups' => 'QA, Team' },
          {'id' => readonly_member.id, 'Name' => 'Read Only Member', 'Sign-in name' => 'read_only_member', 'Email' => readonly_member.email, 'Permissions' => 'readonly_member', 'User groups' => "Team" },
          {'id' => team_member.id, 'Name' => 'Team Member', 'Sign-in name' => 'team_member', 'Email' => team_member.email, 'Permissions' => 'full_member', 'User groups' => "DEV's, Team" }
      ]
      assert_equal expected, project.team_members_with_role_and_group_info.map{ | member | member['id'] = member['id'].to_i ; member}
    end
  end

  def test_team_members_with_role_and_group_info_should_return_all_team_members_when_auto_enrolled_type_is_full
    system_user = User.create_or_update_system_user(login: 'system_user', name: 'System user')
    CurrentLicense.register!( {:licensee =>'barbobo', :max_active_users => '2500' ,:expiration_date => '2008-07-13', :max_light_users => '8', :product_edition => Registration::NON_ENTERPRISE}.to_query, 'barbobo')
    20.times do | count |
      user_name = "user_#{count}"
      User.create!(name: user_name, login: user_name, password: user_name, password_confirmation: user_name)
    end
    users = User.all.sort_by(&:id).map do |user|
      {'id' => user.id, 'Name' => user.name, 'Sign-in name' => user.login, 'Email' => user.email, 'Permissions' => 'full_member', 'User groups' => 'Team'}
    end
    with_new_project do |project|
      project.update_attribute(:auto_enroll_user_type,'full')
      added_user_1 = create_user!(name: 'Added user 1', login:'added_user_1')
      added_user_2 = create_user!(name: 'Added user 2', login:'added_user_2')
      added_user_3 = create_user!(name: 'Added user 3', login:'added_user_3')
      added_user_4 = create_user!(name: 'Added user 4', login:'added_user_4')
      project.add_member(added_user_1)
      project.add_member(added_user_2)
      project.add_member(added_user_3)
      project.add_member(added_user_4)
      expected = [
          {'id' => added_user_1.id, 'Name' => 'Added user 1', 'Sign-in name' => 'added_user_1', 'Email' => added_user_1.email, 'Permissions' => 'full_member', 'User groups' => 'Team'},
          {'id' => added_user_2.id, 'Name' => 'Added user 2', 'Sign-in name' => 'added_user_2', 'Email' => added_user_2.email, 'Permissions' => 'full_member', 'User groups' => 'Team'},
          {'id' => added_user_3.id, 'Name' => 'Added user 3', 'Sign-in name' => 'added_user_3', 'Email' => added_user_3.email, 'Permissions' => 'full_member', 'User groups' => 'Team'},
          {'id' => added_user_4.id, 'Name' => 'Added user 4', 'Sign-in name' => 'added_user_4', 'Email' => added_user_4.email, 'Permissions' => 'full_member', 'User groups' => 'Team'},
      ] + users
      actual_users = project.team_members_with_role_and_group_info(1).map {|member| member['id'] = member['id'].to_i; member}
      assert_equal expected, actual_users
    end
  ensure
    system_user.destroy
  end

  def test_team_members_with_role_and_group_info_should_return_all_team_members_when_auto_enrolled_type_is_readonly
    users = User.all.sort_by(&:id).map do |user|
      {'id' => user.id, 'Name' => user.name, 'Sign-in name' => user.login, 'Email' => user.email, 'Permissions' => 'readonly_member', 'User groups' => 'Team'}
    end
    with_new_project do |project|
      project.update_attribute(:auto_enroll_user_type,'readonly')
      added_user = create_user!(name: 'Added user', login:'added_user')
      project.add_member(added_user)
      expected = [
          {'id' => added_user.id, 'Name' => 'Added user', 'Sign-in name' => 'added_user', 'Email' => added_user.email, 'Permissions' => 'full_member', 'User groups' => 'Team' },
      ] + users

      assert_equal expected, project.team_members_with_role_and_group_info.map{ | member | member['id'] = member['id'].to_i ; member}
    end
  end
  
end
  
