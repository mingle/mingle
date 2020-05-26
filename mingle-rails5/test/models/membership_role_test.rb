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

class MembershipRoleTest < ActiveSupport::TestCase
  def test_lookup_should_return_same_obj_for_same_value
    assert_same MembershipRole[:readonly_member], MembershipRole[:readonly_member]
    assert MembershipRole[:project_admin] != MembershipRole[:readonly_member]
  end

  def test_lookup_role_using_role_object
    assert_same MembershipRole[:project_admin], MembershipRole[MembershipRole[:project_admin]]
  end

  def test_lookup_should_bomb_if_role_value_can_not_be_recognized
    assert_raise(RuntimeError) { MembershipRole[:king] }
  end

  def test_can_compare_a_role_base_on_its_privilege_level
    assert MembershipRole[:project_admin] >  MembershipRole[:full_member]
    assert MembershipRole[:full_member] >  MembershipRole[:readonly_member]

    assert MembershipRole[:project_admin] ==  MembershipRole[:project_admin]

    assert MembershipRole[:full_member] <  MembershipRole[:project_admin]
    assert MembershipRole[:readonly_member] <  MembershipRole[:full_member]

    assert MembershipRole[:readonly_member] <  MembershipRole[:program_admin]
    assert MembershipRole[:program_member] <  MembershipRole[:program_admin]
  end


  def test_all_should_return_project_specific_roles
    roles = MembershipRole.all('Project')
    assert_equal 3, roles.size
    assert roles.include?(MembershipRole[:project_admin])
    assert roles.include?(MembershipRole[:full_member])
    assert roles.include?(MembershipRole[:readonly_member])
  end

  def test_all_should_return_program_specific_roles
    roles = MembershipRole.all('Program')
    assert_equal 2, roles.size
    assert roles.include?(MembershipRole[:program_admin])
    assert roles.include?(MembershipRole[:program_member])
  end

  def test_all_should_return_all_roles
    roles = MembershipRole.all
    assert_equal 5, roles.size
    assert roles.include?(MembershipRole[:program_admin])
    assert roles.include?(MembershipRole[:project_admin])
    assert roles.include?(MembershipRole[:full_member])
    assert roles.include?(MembershipRole[:readonly_member])
    assert roles.include?(MembershipRole[:program_member])
  end

  def test_to_param_should_return_name_and_id_hash
    assert_equal({name: 'Program administrator', id: :program_admin }, MembershipRole[:program_admin].to_param)
    assert_equal({name: 'Program member', id: :program_member}, MembershipRole[:program_member].to_param)
  end
end
