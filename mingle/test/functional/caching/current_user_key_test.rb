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


class CurrentUserKeyTest < ActionController::TestCase
  include CachingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_different_user_should_have_different_user_key
    assert_key_not_changed_after(@project) do
      login_as_member
    end
    
    assert_key_changed_after(@project) do
      login_as_bob
    end
  end
  
  def test_key_should_be_different_when_user_changed_role_for_a_project
    assert_key_changed_after(@project) do
      @project.add_member(User.find_by_login('member'), :project_admin)
    end
  end
  
  private
  
  def key(project)
    KeySegments::CurrentUser.new(project).to_s
  end
end
