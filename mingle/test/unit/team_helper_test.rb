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

class TeamHelperTest < ActionController::TestCase
  include TeamHelper
  
  def setup
    @member = login_as_member
  end

  def test_memberships_json_for_user_and_no_groups
    with_first_project do |project|
      user_with_no_groups = project.users.detect {|u| project.groups_for_member(u).empty?}
      assert_not_nil user_with_no_groups
      assert_equal("{\"#{user_with_no_groups.id}\":[]}", memberships_json_for(project, [user_with_no_groups]))
    end
  end
  
  def test_memberships_json_for_user_and_with_groups
    with_first_project do |project|
      dev = create_group("dev")
      ba = create_group("ba")
      with_first_admin { dev.add_member(@member) }
      assert_equal("{\"#{@member.id}\":[#{dev.id}]}", memberships_json_for(project, [@member]))
    end
  end
end
