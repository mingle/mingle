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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

# Tags:
class MemberRoleTest < ActiveSupport::TestCase

  def setup
    first_project.activate
    @member_roles = first_project.member_roles
  end

  def test_default_role_is_normal_team_member
    user = User.first
    @member_roles.setup_user_role(user, nil)
    assert_equal MembershipRole[:full_member], @member_roles.membership_role(user)
  end

  def test_role_changed_after_assigning_new_role
    member_role = MemberRole.new(:member => User.first)

    member_role.role = :project_admin
    assert_equal MembershipRole[:project_admin], member_role.role

    member_role.role = :readonly_member
    assert_equal MembershipRole[:readonly_member], member_role.role

    member_role.role = :full_member
    assert_equal MembershipRole[:full_member], member_role.role
  end

  def test_role_for_light_user_is_readonly
    member = User.find_by_login("member")
    member.update_attributes(:light => true)
    @member_roles.setup_user_role(member, nil)
    assert_equal MembershipRole[:readonly_member], @member_roles.membership_role(member)
  end

  def test_add_member_with_invalid_role_should_bomb
    longbob = User.find_by_login('longbob')
    assert_raise(RuntimeError) { @member_roles.setup_user_role(longbob, :king) }
  end

  def test_add_member_with_role_not_allowed_should_bomb
    longbob = User.find_by_login('longbob')
    longbob.update_attributes(:light => true)
    assert_raise(RuntimeError) { @member_roles.setup_user_role(longbob, :full_member) }
  end

  def test_user_deliverable_roles_should_return_member_role_for_given_user_and_project
    user = User.first
    member_role = @member_roles.setup_user_role(user, :readonly_member)
    roles = MemberRole.user_deliverable_roles(user, first_project)
    assert_equal(1, roles.size)
    assert_equal(member_role, roles.first)
  end
end
