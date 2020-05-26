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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class PrivilegeActionTest < ActiveSupport::TestCase

  def test_eql
    assert_equal UserAccess::PrivilegeAction.new('controller_name', 'action_name'), UserAccess::PrivilegeAction.new('controller_name', 'action_name')
    assert UserAccess::PrivilegeAction.new('controller_name', 'action_name').eql?(UserAccess::PrivilegeAction.new('controller_name', 'action_name'))
    assert UserAccess::PrivilegeAction.new('controller_name', 'action_name') == (UserAccess::PrivilegeAction.new('controller_name', 'action_name'))

    assert_not_equal UserAccess::PrivilegeAction.new('controller_name', 'action_name'), UserAccess::PrivilegeAction.new('controller_name', 'diff')
    assert_not_equal UserAccess::PrivilegeAction.new('controller_name', 'action_name'), UserAccess::PrivilegeAction.new('diff', 'action_name')
    assert_not_equal UserAccess::PrivilegeAction.new('controller_name', 'action_name'), nil
  end

  def test_hash
    map = {}
    map[UserAccess::PrivilegeAction.new('controller_name', 'action_name')] = true
    assert map[UserAccess::PrivilegeAction.new('controller_name', 'action_name')]
  end

  def test_create_from_string_format
    assert_equal UserAccess::PrivilegeAction.new('controller', 'name'), UserAccess::PrivilegeAction.create('controller:name')
  end

  def test_create_from_hash
    assert_equal UserAccess::PrivilegeAction.new('controller', 'name'), UserAccess::PrivilegeAction.create(:controller => 'controller', :action => 'name')
    assert_equal UserAccess::PrivilegeAction.new('controller', 'name'), UserAccess::PrivilegeAction.create('controller' => 'controller', 'action' => 'name')
  end

  def test_default_action_name
    action = UserAccess::PrivilegeAction.new('controller', nil)
    assert_equal 'index', action.name
  end
  
  def test_default_controller
    Thread.current[:controller_name] = 'fake'
    action = UserAccess::PrivilegeAction.new(nil, 'action')
    assert_equal 'fake', action.controller
  ensure
    Thread.current[:controller_name] = nil
  end

  def test_validate_controller_name
    action = UserAccess::PrivilegeAction.new('not_exist', 'action')
    assert_raise RuntimeError do
      action.validate
    end
  end
end

