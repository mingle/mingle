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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class HasManyMembersTest < ActiveSupport::TestCase
  def setup
    @member = create(:user, admin:true)
    @project = create(:project)
    @project.add_member(@member)
    @project.activate
    @admin = create(:user, admin:true)
    login(@admin)
  end
  
  def test_newly_created_project_should_have_a_team
    assert_not_nil create(:project).team
  end
  
  def test_mingle_admin_should_not_automatically_be_a_member_of_project_that_she_creates
    create(:project) do |project|
      assert_equal 0 , project.users.size
    end
  end
  
  def test_can_get_users_belonging_to_project
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    another_project = create(:project)
    another_project.add_member(user1)
    another_project.add_member(user2)
    another_project.add_member(user3)

    assert_equal 3, another_project.users.size
    another_project.add_member(create(:user))
    assert_equal 4, another_project.reload.users.size
  end
  
  def test_users_belongs_to_project
    assert @project.member?(@member)
    assert !@project.member?(create(:user))
  end
  
  def test_user_should_be_uniq_in_one_project
    user = create(:user)
    create(:project) do |project|
      project.add_member(user)
      project.add_member(user)
      
      assert_equal [user], project.users
    end
  end

  def test_mingle_admin_should_be_project_admin
    assert @project.admin?(@admin)
  end
  
  def test_project_admin_should_be_member
    @user = create(:user)
  
    assert !@project.users.include?(@user)
    assert !@project.member?(@user)
    @project.add_member(@user, :project_admin)
    assert @project.users.include?(@user)
    assert @project.member?(@user)
  end
  
  def test_project_admin
    @user = create(:user)
    assert_false @project.project_admin?(@user)
    @project.add_member(@user, :project_admin)
    assert @project.admin?(@user)
    assert !@user.admin?
  end
  
  def test_all_members_should_still_be_what_role_they_are_when_license_is_invalid
    project_admin = create(:user)
    member = create(:user)
    @project.add_member(project_admin, :project_admin)
    @project.add_member(member)
    clear_license

    assert @project.admin?(project_admin)
    assert !@project.readonly_member?(project_admin)
    assert !@project.readonly_member?(member)
    assert @project.member?(member)
    assert @project.project_admin?(project_admin)

  end
  
  def test_should_add_readonly_member
    user1 = create(:user)
    assert !@project.readonly_member?(user1)

    @project.add_member(user1, :readonly_member)
    assert @project.member?(user1)
    assert @project.readonly_member?(user1)
  end  
  
  def test_user_should_be_not_readonly_project_member_when_user_is_not_in_project
    new_user = create(:user)
    assert !@project.readonly_member?(new_user)
  end
  
  def test_anonymous_user_should_not_be_member_of_any_project
    assert !@project.member?(nil)
    assert !@project.member?(User.anonymous)
  end
  
  def test_non_project_member_should_not_have_any_role
    user = create(:user)

    assert_false @project.admin?(user)
    assert_false @project.readonly_member?(user)
    assert_false @project.member?(user)
    assert_nil @project.role_for(user)
  end
  
  def test_member_should_become_readonly_member_if_he_becomes_light
    user = create(:user)

    @project.add_member(user)
    user.update_attributes(:light => true)

    assert @project.readonly_member?(user)
  end
  
  def test_light_user_should_only_be_readonly_member
    user = create(:user)
    user.update_attributes(:light => true)

    exception = assert_raises(Exception) { @project.add_member(user, :full_member) }
    assert_equal( "#{user.name} cannot have role Team member", exception.message )

    exception = assert_raises(Exception) { @project.add_member(user, :project_admin) }
    assert_equal( "#{user.name} cannot have role Project administrator", exception.message )
  end
  
  def test_project_admin_should_become_readonly_member_if_he_becomes_light
    user = create(:user)
    @project.add_member(user, :project_admin)
    user.update_attributes(:light => true)

    assert @project.readonly_member?(user)
    assert_false @project.admin?(user)
    assert_false @project.project_admin?(user)
  end
  
  def test_remove_member
    user = create(:user)
    @project.add_member(user, :project_admin)
    @project.remove_member(user)
    
    assert_false @project.project_admin?(user)
    assert_false @project.member?(user)
    assert_false @project.readonly_member?(user)
  end

  def test_change_members_role_should_update_role_to_default_role
    user1 = create(:user)
    user2 = create(:user)
    @project.add_member(user1, :project_admin)
    @project.add_member(user2, :project_admin)

    @project.change_members_role([user1.id,user2.id ])

    [user1, user2].each do |user|
      assert @project.member?(user)
    end
  end

  def test_change_members_role_should_update_role_to_given_role
    user1 = create(:user)
    user2 = create(:user)
    @project.add_member(user1)
    @project.add_member(user2)

    @project.change_members_role([user1.id,user2.id], :project_admin)

    [user1, user2].each do |user|
      assert @project.project_admin?(user)
    end
  end

  def test_should_group_members_by_project
    project1 = create(:project)
    project2 = create(:project)
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    project1.add_member(user1)
    project1.add_member(user2)
    project2.add_member(user2)
    project2.add_member(user3)

    expected = project2.class.group_users_by_deliverable

    assert expected[project1.id].include?(user1.id)
    assert expected[project1.id].include?(user2.id)
    assert expected[project2.id].include?(user2.id)
    assert expected[project2.id].include?(user3.id)

    assert_false expected[project1.id].include?(user3.id)
    assert_false expected[project2.id].include?(user1.id)

  end

  def test_should_group_members_by_program
    program1 = create(:program)
    program2 = create(:program)
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    program1.add_member(user1)
    program1.add_member(user2)
    program2.add_member(user2)
    program2.add_member(user3)

    expected = program2.class.group_users_by_deliverable

    assert expected[program1.id].include?(user1.id)
    assert expected[program1.id].include?(user2.id)
    assert expected[program2.id].include?(user2.id)
    assert expected[program2.id].include?(user3.id)

    assert_false expected[program1.id].include?(user3.id)
    assert_false expected[program2.id].include?(user1.id)

  end
  
end
  
