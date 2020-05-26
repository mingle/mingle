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
require File.expand_path(File.dirname(__FILE__) + '/./../user_access_test_helper')

class PlannerUserAccessTest < ActiveSupport::TestCase
  include UserAccess

  def setup
    @admin = User.find_by_login('admin')
    @program_member = User.find_by_login('member')
    @registered_user = User.find_by_login('longbob')
    @program = program('simple_program')
    @program.add_member(@program_member)
  end

  def test_should_be_able_to_recognize_planner_actions
    action = UserAccess::PrivilegeAction.create("programs:create")
    assert action.planner_action?
    assert !UserAccess::PrivilegeAction.create("cards:new").planner_action?
  end

  def test_default_test_license_is_enterprise
    assert CurrentLicense.status.enterprise?
  end

  def test_should_not_be_able_to_access_planner_controllers_when_license_is_not_enterprise
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    assert !CurrentLicense.status.enterprise?

    assert_mingle_admin_cant_access_to(:controller => 'programs', :action => 'index')
    assert_mingle_admin_cant_access_to(:controller => 'programs', :action => 'create')
    assert_mingle_admin_cant_access_to(:controller => 'programs', :action => 'show')

    assert_mingle_admin_cant_access_to(:controller => 'plans', :action => 'update')
    assert_mingle_admin_cant_access_to(:controller => 'plans', :action => 'show')

    assert_mingle_admin_cant_access_to(:controller => 'objectives', :action => 'show')
    assert_mingle_admin_cant_access_to(:controller => 'objectives', :action => 'create')
    assert_mingle_admin_cant_access_to(:controller => 'objectives', :action => 'update')

    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'bulk_create')
    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'bulk_delete')

    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'index')
    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'cards')
  end

  def test_should_be_able_to_access_planner_controllers_when_license_is_enterprise
    register_license(:product_edition => Registration::ENTERPRISE)
    assert CurrentLicense.status.enterprise?

    assert_registered_user_access_to(:controller => 'programs', :action => 'index')
    assert_program_member_access_to(:controller => 'programs', :action => 'show')
    assert_only_mingle_admin_access_to(:controller => 'programs', :action => 'create')

    assert_program_member_access_to(:controller => 'plans', :action => 'update')
    assert_program_member_access_to(:controller => 'plans', :action => 'show')

    assert_program_member_access_to(:controller => 'objectives', :action => 'show')
    assert_program_member_access_to(:controller => 'objectives', :action => 'create')
    assert_program_member_access_to(:controller => 'objectives', :action => 'update')

    assert_program_member_access_to(:controller => 'works', :action => 'index')
    assert_program_member_access_to(:controller => 'works', :action => 'cards')
    assert_program_member_access_to(:controller => 'works', :action => 'bulk_create')
    assert_program_member_access_to(:controller => 'works', :action => 'bulk_delete')

    assert_program_member_access_to(:controller => 'program_export', :action => 'index')
    assert_program_member_access_to(:controller => 'program_export', :action => 'create')
    assert_program_member_access_to(:controller => 'program_export', :action => 'download')

    assert_program_member_access_to(:controller => 'program_memberships', :action => 'index')
    assert_program_member_access_to(:controller => 'program_memberships', :action => 'create')
    assert_program_member_access_to(:controller => 'program_memberships', :action => 'list_users_for_add')
    assert_program_member_access_to(:controller => 'program_memberships', :action => 'bulk_destroy')
  end

  def test_should_not_be_able_to_access_planner_controllers_when_license_is_expired
    register_license(:product_edition => Registration::ENTERPRISE, :expiration_date => '2001-01-01')
    assert !CurrentLicense.status.valid?
    assert CurrentLicense.status.enterprise?

    assert_mingle_admin_cant_access_to(:controller => 'programs', :action => 'index')
    assert_mingle_admin_cant_access_to(:controller => 'programs', :action => 'create')
    assert_mingle_admin_cant_access_to(:controller => 'programs', :action => 'show')

    assert_mingle_admin_cant_access_to(:controller => 'plans', :action => 'update')
    assert_mingle_admin_cant_access_to(:controller => 'plans', :action => 'show')

    assert_mingle_admin_cant_access_to(:controller => 'objectives', :action => 'show')
    assert_mingle_admin_cant_access_to(:controller => 'objectives', :action => 'create')
    assert_mingle_admin_cant_access_to(:controller => 'objectives', :action => 'update')

    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'index')
    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'cards')
    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'bulk_create')
    assert_mingle_admin_cant_access_to(:controller => 'works', :action => 'bulk_delete')
  end

  def assert_program_member_access_to(action)
    @program_member.with_current do
      assert authorized?(action), "program member is able to access #{action.inspect}"
    end
    @registered_user.with_current do |user|
      assert !authorized?(action), "registered user should NOT be able to access #{action.inspect}"
    end
  end

  def assert_only_mingle_admin_access_to(action)
    @admin.with_current do
      assert authorized?(action), "mingle admin should be able to access #{action.inspect}"
    end

    @program_member.with_current do
      assert !authorized?(action), "only mingle admin is able to access #{action.inspect}"
    end
  end

  #should only use this in test that license is invalid
  def assert_mingle_admin_cant_access_to(action)
    @admin.with_current do
      assert !authorized?(action), "mingle admin should NOT be able to access #{action.inspect}"
    end
  end

  def assert_registered_user_cant_access_to(action)
    @registered_user.with_current do
      assert !authorized?(action), "registered user should NOT be able to access #{action.inspect}"
    end
  end

  def assert_registered_user_access_to(action)
    @registered_user.with_current do |user|
      assert authorized?(action), "registered user should be able to access #{action.inspect}"
    end
    User.current = nil
    assert !authorized?(action), "anonymous user should NOT be able to access #{action.inspect}"
  end

end
