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

module UserAccessTestHelper
  include UserAccess

  def create_anonymous_project
    User.find_by_login('admin').with_current do |user|
      create(:project) do |project|
        project.update_attribute :anonymous_accessible, true
        project
      end
    end
  end

  def assert_only_mingle_admin_access_to(action)
    User.find_by_login('admin').with_current do
      assert authorized?(action), "mingle admin should be able to access #{action.inspect}"
    end

    User.find_by_login('project_admin').with_current do
      assert !authorized?(action), "only mingle admin is able to access #{action.inspect}"
    end
  end

  #should only use this in test that license is invalid
  def assert_mingle_admin_cant_access_to(action)
    User.find_by_login('admin').with_current do
      assert !authorized?(action), "mingle admin should NOT be able to access #{action.inspect}"
    end
  end

  def assert_project_admin_cant_access_to(action)
    User.find_by_login('project_admin').with_current do
      assert !authorized?(action), "project admin should NOT be able to access #{action.inspect}"
    end
  end

  def assert_registered_user_cant_access_to(action)
    User.find_by_login('registered_user').with_current do
      assert !authorized?(action), "registered user should NOT be able to access #{action.inspect}"
    end
  end

  def assert_github_user_cant_access(action)
    User.find_by_login('github').with_current do
      assert !authorized?(action), "github user should NOT be able to access #{action.inspect}"
    end
  end

  def assert_github_user_access_to(action)
    User.find_by_login('github').with_current do
      assert authorized?(action), "github user should be able to access #{action.inspect}"
    end
  end

  def assert_project_admin_access_to(action)
    User.find_by_login('project_admin').with_current do
      assert authorized?(action), "project admin should be able to access #{action.inspect}"
    end
    User.find_by_login('member').with_current do
      assert !authorized?(action), "only proj/mingle admin is able to access #{action.inspect}"
    end
  end

  def assert_project_full_team_member_access_to(action)
    User.find_by_login('member').with_current do |user|
      assert authorized?(action), "full team member should be able to access #{action.inspect}"
    end
    User.find_by_login('read_only_user').with_current do |user|
      Project.current.add_member(user, :readonly_member)
      assert !authorized?(action), "readonly team member should NOT be able to access #{action.inspect}"
    end
  end

  def assert_project_readonly_member_access_to(action)
    User.find_by_login('member').with_current do |user|
      Project.current.add_member(user, :readonly_member)
      assert authorized?(action), "readonly team member should be able to access #{action.inspect}"
    end
    User.find_by_login('read_only_user').with_current do |user|
      Project.current.add_member(user, :readonly_member)
      user.update_attribute :light, true
      assert !authorized?(action), "light team member should NOT be able to access #{action.inspect}"
    end
  end

  def assert_project_light_readonly_member_access_to(action)
    User.find_by_login('read_only_user').with_current do |user|
      Project.current.add_member(user, :readonly_member)
      user.update_attribute :light, true
      assert authorized?(action), "light team member should be able to access #{action.inspect}"
    end
    User.current = nil
    assert !authorized?(action), "anonymous user should NOT be able to access #{action.inspect}"
  end

  def assert_registered_user_access_to(action)
    User.find_by_login('registered_user').with_current do |user|
      assert authorized?(action), "light team member should be able to access #{action.inspect}"
    end
    User.current = nil
    assert !authorized?(action), "anonymous user should NOT be able to access #{action.inspect}"
  end

  def assert_light_user_access_to(action)
    User.find_by_login('read_only_user').with_current do |user|
      user.update_attribute :light, true
      assert authorized?(action), "light user should be able to access #{action.inspect}"
    end
    User.current = nil
    assert !authorized?(action), "anonymous user should NOT be able to access #{action.inspect}"
  end
end
