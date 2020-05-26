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

class UserMembershipTest < ActiveSupport::TestCase
  # User_memberships does not have uniq constraint on user_id and
  # group_id;
  # Hence, there is possibility that one user has multiple
  # user_memberships.
  # instead of clean up data and add constraint, we decide to just
  # clean up data when remove user from team
  def test_should_delete_all_user_memberships_when_remove_member_from_team
    bob = User.find_by_login('bob')
    with_project_without_cards do |project|
      project.add_member(bob)
    end

    with_first_project do |project|
      Project.connection.execute("insert into user_memberships (id, user_id, group_id) values (#{Project.connection.next_id_sql('user_memberships')}, #{bob.id}, #{project.team.id})")

      bob_ums = project.team.user_memberships.select {|um| um.user_id == bob.id}
      assert bob_ums.size > 1
      project.remove_member(bob)
      project.reload
      bob_ums = project.team.user_memberships.select {|um| um.user_id == bob.id}
      assert_equal 0, bob_ums.size
    end

    with_project_without_cards do |project|
      assert project.member?(bob)
    end
  end
end
