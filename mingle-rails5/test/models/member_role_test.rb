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

class MemberRoleTest < ActiveSupport::TestCase

  def setup
    @project = create(:project)
    @first_user = create(:user, name: 'first user')
    @first_user.save validate:false
    @member_roles = @project.member_roles
  end

  def test_default_role_is_normal_team_member
    @member_roles.setup_user_role(@first_user, nil)
    assert_equal MembershipRole[:full_member], @member_roles.membership_role(@first_user)
  end

  def test_role_changed_after_assigning_new_role
    member_role = MemberRole.new(:member => @first_user)

    member_role.role = :project_admin
    assert_equal MembershipRole[:project_admin], member_role.role

    member_role.role = :readonly_member
    assert_equal MembershipRole[:readonly_member], member_role.role

    member_role.role = :full_member
    assert_equal MembershipRole[:full_member], member_role.role

    member_role.role = :program_admin
    assert_equal MembershipRole[:program_admin], member_role.role
  end

  def test_role_for_light_user_is_readonly
    light_user = create(:light_user)
    @member_roles.setup_user_role(light_user,nil)
    assert_equal MembershipRole[:readonly_member], @member_roles.membership_role(light_user)
  end

  def test_add_member_with_invalid_role_should_bomb
    longbob = create(:user, name: 'longbob')
    assert_raise(RuntimeError) { @member_roles.setup_user_role(longbob, :king) }
  end

  def test_add_member_with_role_not_allowed_should_bomb
    longbob = create(:light_user, name: 'longbob')
    assert_raise(RuntimeError) { @member_roles.setup_user_role(longbob, :full_member) }
  end

  def test_user_deliverable_roles_should_return_member_role_for_given_user_and_project
    user = @first_user
    member_role = @member_roles.setup_user_role(user, :readonly_member)
    roles = MemberRole.user_deliverable_roles(user, @project)
    assert_equal(1, roles.size)
    assert_equal(member_role, roles.first)
  end

  def test_admin_check_should_check_for_program_admin_for_given_program
    program = create(:program)
    user = create(:user)
    member_roles = program.member_roles
    member_roles.setup_user_role(user, :program_admin)
    assert program.admin?(user)
  end

  def test_admin_check_should_check_for_program_admin_for_given_program_for_program_member
    program = create(:program)
    user = create(:user)
    member_roles = program.member_roles
    member_roles.setup_user_role(user, :program_member)
    assert_false program.admin?(user)
  end
end
