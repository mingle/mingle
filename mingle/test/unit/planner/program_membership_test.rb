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

class ProgramMembershipTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = program('simple_program')
  end

  def test_program_can_add_team_member
    member = User.find_by_login('member')

    @program.add_member member
    assert @program.member?(member)
    assert_equal [member], @program.users
  end

  def test_program_can_remove_team_member
    member = User.find_by_login('member')

    @program.add_member member
    @program.remove_member member
    assert !@program.member?(member)
  end

  def test_program_team_member_role_is_full_team_member
    member = User.find_by_login('member')
    @program.add_member member

    @program.users.each do | member |
      assert @program.full_member?(member), "#{member.name} is not a full member of program #{@program.name}"
      assert !@program.admin?(member)
      assert !@program.readonly_member?(member)
      assert !@program.project_admin?(member)
      assert_equal MembershipRole[:full_member], @program.role_for(member)
    end
  end

  def test_adding_member_to_project_should_not_add_member_to_program
    project = first_project
    bob = User.find_by_login('bob')
    project.add_member(bob)
    assert_false @program.member?(bob)
    @program.projects << project
    assert !@program.member?(bob)
  end
end
