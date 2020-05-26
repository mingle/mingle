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
require File.expand_path(File.dirname(__FILE__) + '/./user_access_test_helper')
require "delegate"

class UserAccessTest < ActiveSupport::TestCase
  include UserAccessTestHelper

  def test_project_action
    assert PrivilegeAction.create(:controller => 'cards', :action => 'index').project_action?
    assert !PrivilegeAction.create(:controller => 'users', :action => 'index').project_action?
    assert !PrivilegeAction.create(:controller => 'plans', :action => 'index').project_action?
  end

  def test_mingle_admin_privilege_level
    admin = User.find_by_login("admin")
    assert_equal PrivilegeLevel::MINGLE_ADMIN, admin.privilege_level
    assert_equal PrivilegeLevel::MINGLE_ADMIN, admin.privilege_level(create_project)
    assert_equal PrivilegeLevel::MINGLE_ADMIN, admin.privilege_level(create_anonymous_project)
  end

  def test_project_admin_privilege_level
    project_admin = User.find_by_login('proj_admin')

    assert_equal PrivilegeLevel::PROJECT_ADMIN, project_admin.privilege_level(nil)
    assert_equal PrivilegeLevel::REGISTERED_USER, project_admin.privilege_level(create_project)

    assert first_project.admin?(project_admin)
    assert_equal PrivilegeLevel::PROJECT_ADMIN, project_admin.privilege_level(first_project)
    assert_equal PrivilegeLevel::REGISTERED_USER, project_admin.privilege_level(create_anonymous_project)
  end

  def test_project_team_member_privilege_level
    user = User.find_by_login('first')
    assert_equal PrivilegeLevel::FULL_TEAM_MEMBER, user.privilege_level(first_project)

    assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(nil)
    assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_project)
    assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_anonymous_project)
  end

  def test_project_readonly_team_member_privilege_level
    User.find_by_login('member').with_current do |user|
      project = create_project
      project.add_member(user, :readonly_member)
      assert_equal PrivilegeLevel::READONLY_TEAM_MEMBER, user.privilege_level(project)

      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(nil)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_project)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_anonymous_project)
    end
  end

  def test_project_full_team_member_privilege_level
    User.find_by_login('member').with_current do |user|
      project = create_project
      project.add_member(user, :full_member)
      assert_equal PrivilegeLevel::FULL_TEAM_MEMBER, user.privilege_level(project)

      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(nil)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_project)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_anonymous_project)
    end
  end

  def test_light_project_readonly_team_member_privilege_level
    create_user!(:name => 'iamweird').with_current do |user|
      project = create_project
      project.add_member(user, :readonly_member)
      user.update_attribute :light, true
      assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, user.privilege_level(project)

      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(nil)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_project)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.privilege_level(create_anonymous_project)
    end
  end

  def test_anonymous_user_privilege_level
    assert_equal PrivilegeLevel::ANONYMOUS, User.anonymous.privilege_level
    assert_equal PrivilegeLevel::ANONYMOUS, User.anonymous.privilege_level(first_project)
  end

  def test_mingle_admin_privilege_level_when_license_is_invalid
    clear_license
    admin = User.find_by_login("admin")
    assert_equal PrivilegeLevel::REGISTERED_USER, admin.license_invalid_privilege_level
    assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, admin.license_invalid_privilege_level(create_project)
    assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, admin.license_invalid_privilege_level(create_anonymous_project)
  end

  def test_project_admin_privilege_level_when_license_is_invalid
    clear_license
    project_admin = User.find_by_login('proj_admin')
    assert_equal PrivilegeLevel::REGISTERED_USER, project_admin.license_invalid_privilege_level(nil)
    assert_equal PrivilegeLevel::REGISTERED_USER, project_admin.license_invalid_privilege_level(create_project)

    # assert first_project.admin?(project_admin) todo: add it back after we remove License::LicenseViolation
    assert first_project.project_admin?(project_admin)
    assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, project_admin.license_invalid_privilege_level(first_project)
    assert_equal PrivilegeLevel::REGISTERED_USER, project_admin.license_invalid_privilege_level(create_anonymous_project)
  end

  def test_project_full_team_member_privilege_level_when_license_is_invalid
    clear_license
    user = User.find_by_login('first')
    assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, user.license_invalid_privilege_level(first_project)

    assert_equal PrivilegeLevel::REGISTERED_USER, user.license_invalid_privilege_level(nil)
    assert_equal PrivilegeLevel::REGISTERED_USER, user.license_invalid_privilege_level(create_project)
    assert_equal PrivilegeLevel::REGISTERED_USER, user.license_invalid_privilege_level(create_anonymous_project)
  end

  def test_project_readonly_team_member_privilege_level_when_license_is_invalid
    clear_license
    User.find_by_login('member').with_current do |user|
      project = create_project
      project.add_member(user, :readonly_member)
      assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, user.license_invalid_privilege_level(project)

      assert_equal PrivilegeLevel::REGISTERED_USER, user.license_invalid_privilege_level(nil)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.license_invalid_privilege_level(create_project)
      assert_equal PrivilegeLevel::REGISTERED_USER, user.license_invalid_privilege_level(create_anonymous_project)
    end
  end

  def test_should_always_be_authorized_when_given_non_action
    cached_controller_name = Thread.current[:controller_name]
    random_failure_error_msg = "If you see this test failing randomly, it might be caused by the cached value of controller name => #{cached_controller_name}"
    assert authorized?({}), random_failure_error_msg
    assert authorized?(''), random_failure_error_msg
    assert authorized?(nil), random_failure_error_msg
  end

  def test_anonymous_user_privilege_level_when_license_is_invalid
    assert_equal PrivilegeLevel::ANONYMOUS, User.anonymous.license_invalid_privilege_level
    assert_equal PrivilegeLevel::ANONYMOUS, User.anonymous.license_invalid_privilege_level(first_project)
  end

  def test_anonymous_project_team_members_privilege_level
    User.find_by_login('admin').with_current do |user|
      proj_admin = User.find_by_login('proj_admin')
      member = User.find_by_login('member')
      @project = create_project(:users => [member], :admins => [proj_admin])
      @project.update_attribute :anonymous_accessible, true
      assert_equal PrivilegeLevel::PROJECT_ADMIN, proj_admin.privilege_level(@project)
      assert_equal PrivilegeLevel::FULL_TEAM_MEMBER, member.privilege_level(@project)
    end
  end

  def test_non_team_members_access_anonymous_project
    User.find_by_login('admin').with_current do |user|
      @project = create_project
      @project.update_attribute :anonymous_accessible, true
    end
    User.with_current(User.anonymous) do |user|
      anonymous_member_access = {:controller => 'cards', :action => 'show'}
      assert authorized?(anonymous_member_access)
      full_team_member_access = {:controller => 'cards', :action => 'new'}
      project_readonly_member_access = {:controller => 'cards', :action => 'copy'}
      assert !authorized?(full_team_member_access)
      assert !authorized?(project_readonly_member_access)
    end
  end

  def test_compare_privilege_levels
    assert PrivilegeLevel::MINGLE_ADMIN > PrivilegeLevel::PROJECT_ADMIN
    assert PrivilegeLevel::PROJECT_ADMIN > PrivilegeLevel::FULL_TEAM_MEMBER
    assert PrivilegeLevel::FULL_TEAM_MEMBER > PrivilegeLevel::READONLY_TEAM_MEMBER
    assert PrivilegeLevel::READONLY_TEAM_MEMBER > PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER
    assert PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER > PrivilegeLevel::REGISTERED_USER
    assert PrivilegeLevel::REGISTERED_USER > PrivilegeLevel::ANONYMOUS
  end

  def test_action_minimum_privilege_level
    assert_equal PrivilegeLevel::MINGLE_ADMIN, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('license:show'))
    assert_equal PrivilegeLevel::PROJECT_ADMIN, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('users:list'))
    assert_equal PrivilegeLevel::PROJECT_ADMIN, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('projects:update'))
    assert_equal PrivilegeLevel::FULL_TEAM_MEMBER, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('cards:create'))
    assert_equal PrivilegeLevel::READONLY_TEAM_MEMBER, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('cards:copy'))
    assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('projects:export'))
    assert_equal PrivilegeLevel::ANONYMOUS, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('cards:show'))
    assert_equal PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER, PrivilegeLevel.find_minimum_privilege_level_for(PrivilegeAction.create('plans:show'))
  end


  def test_should_not_have_write_access_when_readonly_mode_is_on
    admin_user = create_user!(admin: true)
    registered_user = create_user!
    with_new_project do |project|
      project.add_member(admin_user, :project_admin)
      project.add_member(registered_user)
    end
    MingleConfiguration.with_readonly_mode_overridden_to(true) do
      login(admin_user)
      assert_false authorized?(controller: :projects, action: :create)
      assert_false authorized?(controller: :cards, action: :create)
      assert authorized?(controller: :projects, action: :list)

      login(registered_user)
      assert_false authorized?(controller: :projects, action: :create)
      assert_false authorized?(controller: :cards, action: :create)
      assert authorized?(controller: :projects, action: :list)
    end
  end

  def test_should_authorized_mingle_admin_for_whitelisted_actions_when_readonly_mode_is_on
    admin_user = create_user!(admin: true)
    registered_user = create_user!
    MingleConfiguration.with_readonly_mode_overridden_to(true) do
      privilege_actions = [{controller: :exports, actions: [:download, :create]},
                  {controller: :users, actions: [:index, :list, :plan]},
                  {controller: :dependencies_import_export, actions: [:index, :create, :download]},
                  {controller: :integrations, actions:[:index, :remove_slack_integration]},
                 {controller: :sso_config, actions:[:show]},
                 {controller: :sysadmin, actions:[:toggle_show_all_project_admins]}]
      assert_user_privileges(admin_user, privilege_actions, true)
      assert_user_privileges(registered_user, privilege_actions, false)
    end
  end


  def test_should_handle_string_keys
    assert_only_mingle_admin_access_to 'controller' => 'projects', 'action' => 'new'
  end

  def test_should_handle_symbol_values
    assert_only_mingle_admin_access_to :controller => :projects, :action => :new
  end

  def test_what_actions_does_mingle_admin_access_only_when_license_is_invalid
    clear_license
    assert_only_mingle_admin_access_to :controller => 'license', :action => 'show'
    assert_only_mingle_admin_access_to :controller => 'license', :action => 'update'

    assert_only_mingle_admin_access_to :controller => 'users', :action => 'toggle_activate'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'toggle_light'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'list'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'index'

    assert_only_mingle_admin_access_to :controller => 'exports', :action => 'create'
    assert_only_mingle_admin_access_to :controller => 'exports', :action => 'download'

    #license valid can access, but now, can't
    assert_mingle_admin_cant_access_to :controller => 'projects', :action => 'new'
    assert_mingle_admin_cant_access_to :controller => 'projects', :action => 'create'
    assert_mingle_admin_cant_access_to :controller => 'projects', :action => 'delete'
    assert_mingle_admin_cant_access_to :controller => 'projects', :action => 'confirm_delete'
    assert_mingle_admin_cant_access_to :controller => 'projects', :action => 'import'

    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'new'
    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'create'
    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'edit_profile'
    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'update_profile'
    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'change_password'
    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'update_password'
    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'toggle_admin'
    assert_mingle_admin_cant_access_to :controller => 'users', :action => 'delete'
    assert_mingle_admin_cant_access_to :controller => 'smtp', :action => 'edit'
    assert_mingle_admin_cant_access_to :controller => 'smtp', :action => 'update'
    assert_mingle_admin_cant_access_to :controller => 'smtp', :action => 'test'

    assert_mingle_admin_cant_access_to :controller => 'templates', :action => 'index'
    assert_mingle_admin_cant_access_to :controller => 'templates', :action => 'new'
    assert_mingle_admin_cant_access_to :controller => 'templates', :action => 'delete'
    assert_mingle_admin_cant_access_to :controller => 'templates', :action => 'confirm_delete'
    assert_mingle_admin_cant_access_to :controller => 'templates', :action => 'templatize'

    assert_mingle_admin_cant_access_to :controller => 'project_import', :action => 'import'
    assert_mingle_admin_cant_access_to :controller => 'project_import', :action => 'index'

    #can still access registered user level actions
    assert_mingle_admin_access_to = lambda do |action|
      User.find_by_login('admin').with_current do
        assert authorized?(action), "mingle admin should be able to access #{action.inspect}"
      end
    end
    assert_mingle_admin_access_to.call :controller => 'projects', :action => 'index'
    assert_mingle_admin_access_to.call :controller => 'projects', :action => 'show'
    assert_mingle_admin_access_to.call :controller => 'cards', :action => 'show'
  end

  def test_what_actions_does_non_mingle_admin_could_access_when_license_is_invalid
    clear_license
    with_first_project do |project|
      @project = project
      assert_project_light_readonly_member_access_to :controller => 'team', :action => 'show_member_email'

      # this is the only few actions that minimum privilege level is readonly member
      assert_project_admin_cant_access_to :controller => 'cards', :action => 'copy'
    end
    assert_registered_user_access_to :controller => 'projects', :action => 'request_membership'
  end

  def test_what_actions_does_mingle_admin_access_only_when_license_is_valid
    assert_only_mingle_admin_access_to :controller => 'license', :action => 'show'
    assert_only_mingle_admin_access_to :controller => 'license', :action => 'update'

    assert_only_mingle_admin_access_to :controller => 'users', :action => 'toggle_activate'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'toggle_light'

    assert_only_mingle_admin_access_to :controller => 'projects', :action => 'new'
    assert_only_mingle_admin_access_to :controller => 'projects', :action => 'create'
    assert_only_mingle_admin_access_to :controller => 'projects', :action => 'delete'
    assert_only_mingle_admin_access_to :controller => 'projects', :action => 'confirm_delete'
    assert_only_mingle_admin_access_to :controller => 'projects', :action => 'import'

    assert_only_mingle_admin_access_to :controller => 'users', :action => 'new'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'create'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'edit_profile'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'update_profile'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'change_password'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'update_password'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'toggle_admin'
    assert_only_mingle_admin_access_to :controller => 'users', :action => 'delete'
    assert_only_mingle_admin_access_to :controller => 'smtp', :action => 'edit'
    assert_only_mingle_admin_access_to :controller => 'smtp', :action => 'update'
    assert_only_mingle_admin_access_to :controller => 'smtp', :action => 'test'

    assert_only_mingle_admin_access_to :controller => 'templates', :action => 'index'
    assert_only_mingle_admin_access_to :controller => 'templates', :action => 'new'
    assert_only_mingle_admin_access_to :controller => 'templates', :action => 'delete'
    assert_only_mingle_admin_access_to :controller => 'templates', :action => 'confirm_delete'
    assert_only_mingle_admin_access_to :controller => 'templates', :action => 'templatize'

    assert_only_mingle_admin_access_to :controller => 'project_import', :action => 'import'
    assert_only_mingle_admin_access_to :controller => 'project_import', :action => 'index'
  end

  def test_what_actions_does_project_admin_access_only_outside_project
    assert_project_admin_access_to :controller => 'users', :action => 'show'
    assert_project_admin_access_to :controller => 'users', :action => 'select_project_assignments'
    assert_project_admin_access_to :controller => 'users', :action => 'assign_to_projects'
    assert_project_admin_access_to :controller => 'users', :action => 'list'
    assert_project_admin_access_to :controller => 'users', :action => 'index'
    assert_project_admin_access_to :controller => 'users'
  end

  def test_what_actions_does_project_admin_access_only_inside_project
    with_project_without_cards do |project|
      project.add_member(User.find_by_login('member'), :project_admin)
    end
    with_first_project do |project|
      @project = project
      assert_project_admin_access_to :controller => 'projects', :action => 'update'
      assert_project_admin_access_to :controller => 'projects', :action => 'edit'
      assert_project_admin_access_to :controller => 'projects', :action => 'regenerate_changes'
      assert_project_admin_access_to :controller => 'projects', :action => 'recache_revisions'
      assert_project_admin_access_to :controller => 'projects', :action => 'regenerate_secret_key'
      assert_project_admin_access_to :controller => 'projects', :action => 'advanced'
      assert_project_admin_access_to :controller => 'projects', :action => 'recompute_aggregates'
      assert_project_admin_access_to :controller => 'projects', :action => 'rebuild_card_murmur_linking'
      assert_project_admin_access_to :controller => 'team', :action => 'add_user_to_team'
      assert_project_admin_access_to :controller => 'team', :action => 'destroy'
      assert_project_admin_access_to :controller => 'team', :action => 'set_permission'
      assert_project_admin_access_to :controller => 'team', :action => 'enable_auto_enroll'

      assert_project_admin_access_to :controller => 'group_memberships', :action => 'update'

      assert_project_admin_access_to :controller => 'pages', :action => 'destroy'

      assert_project_admin_access_to :controller => 'property_definitions', :action => 'new'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'create'

      assert_project_admin_access_to :controller => 'property_definitions', :action => 'reorder'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'edit'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'update'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'confirm_hide'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'hide'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'unhide'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'toggle_restricted'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'confirm_delete'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'delete'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'toggle_transition_only'
      assert_project_admin_access_to :controller => 'property_definitions', :action => 'confirm_update'

      assert_project_admin_access_to :controller => 'enumeration_values', :action => 'create'
      assert_project_admin_access_to :controller => 'enumeration_values', :action => 'update_name'
      assert_project_admin_access_to :controller => 'enumeration_values', :action => 'destroy'
      assert_project_admin_access_to :controller => 'enumeration_values', :action => 'update_color'
      assert_project_admin_access_to :controller => 'enumeration_values', :action => 'confirm_delete'

      assert_project_admin_access_to :controller => 'cards', :action => 'update_property_color'

      assert_project_admin_access_to :controller => 'transitions', :action => 'new'
      assert_project_admin_access_to :controller => 'transitions', :action => 'create'
      assert_project_admin_access_to :controller => 'transitions', :action => 'edit'
      assert_project_admin_access_to :controller => 'transitions', :action => 'update'
      assert_project_admin_access_to :controller => 'transitions', :action => 'destroy'

      assert_project_admin_access_to :controller => 'projects', :action => 'update_keywords'

      assert_project_admin_access_to :controller => 'cards', :action => 'destroy'
      assert_project_admin_access_to :controller => 'cards', :action => 'bulk_destroy'

      assert_project_admin_access_to :controller => 'card_types', :action => 'new'
      assert_project_admin_access_to :controller => 'card_types', :action => 'create'
      assert_project_admin_access_to :controller => 'card_types', :action => 'edit'
      assert_project_admin_access_to :controller => 'card_types', :action => 'update'
      assert_project_admin_access_to :controller => 'card_types', :action => 'confirm_delete'
      assert_project_admin_access_to :controller => 'card_types', :action => 'delete'
      assert_project_admin_access_to :controller => 'card_types', :action => 'update_color'
      assert_project_admin_access_to :controller => 'card_types', :action => 'reorder'
      assert_project_admin_access_to :controller => 'card_types', :action => 'preview'
      assert_project_admin_access_to :controller => 'card_types', :action => 'chart'
      assert_project_admin_access_to :controller => 'card_types', :action => 'confirm_update'

      assert_project_admin_access_to :controller => 'favorites', :action => 'move_to_team_favorite'
      assert_project_admin_access_to :controller => 'favorites', :action => 'delete'
      assert_project_admin_access_to :controller => 'favorites', :action => 'move_to_tab'
      assert_project_admin_access_to :controller => 'favorites', :action => 'remove_tab'

      assert_project_admin_access_to :controller => 'card_trees', :action => 'update_aggregate_property_definition'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'delete'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'new'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'show_edit_aggregate_form'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'edit_aggregate_properties'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'edit'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'create_aggregate_property_definition'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'create'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'show_add_aggregate_form'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'delete_aggregate_property_definition'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'update'
      assert_project_admin_access_to :controller => 'card_trees', :action => 'confirm_delete'

      assert_project_admin_access_to :controller => 'project_variables', :action => 'create'
      assert_project_admin_access_to :controller => 'project_variables', :action => 'update'
      assert_project_admin_access_to :controller => 'project_variables', :action => 'new'
      assert_project_admin_access_to :controller => 'project_variables', :action => 'edit'
      assert_project_admin_access_to :controller => 'project_variables', :action => 'delete'
      assert_project_admin_access_to :controller => 'project_variables', :action => 'select_data_type'
      assert_project_admin_access_to :controller => 'project_variables', :action => 'select_card_type'
      assert_project_admin_access_to :controller => 'project_variables', :action => 'confirm_update'

      assert_project_admin_access_to :controller => 'repository', :action => 'index'
      assert_project_admin_access_to :controller => 'repository', :action => 'show'
      assert_project_admin_access_to :controller => 'repository', :action => 'delete'
      assert_project_admin_access_to :controller => 'repository', :action => 'configure'
      assert_project_admin_access_to :controller => 'repository', :action => 'save'
      assert_project_admin_access_to :controller => 'repository', :action => 'update'
      assert_project_admin_access_to :controller => 'repository', :action => 'create'

      assert_project_admin_access_to :controller => 'groups', :action => 'update'
      assert_project_admin_access_to :controller => 'groups', :action => 'create'
      assert_project_admin_access_to :controller => 'groups', :action => 'destroy'

      assert_project_admin_access_to :controller => 'group_memberships', :action => 'update'
      assert_project_admin_access_to :controller => 'group_memberships', :action => 'add'
    end
  end

  def test_what_actions_does_project_member_access
    with_first_project do |project|
      @project = project
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'new'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'create'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'edit'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'update'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'preview'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'update_property'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'bulk_set_properties_panel'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'bulk_set_properties'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'bulk_tagging_panel'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'remove_card_from_tree'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'create_view'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'bulk_transition'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'transition'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'bulk_transition'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'transition_in_popup'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'require_popup_for_transition'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'require_popup_for_transition_in_popup'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'require_comment_for_bulk_transition'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'remove_attachment'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'set_value_for'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'tree_cards_quick_add'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'add_children'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'bulk_add_tags'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'bulk_remove_tag'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'update_tags'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'add_comment'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'show_tree_cards_quick_add'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'show_tree_cards_quick_add_to_root'
      assert_project_full_team_member_access_to :controller => 'cards', :action => 'show_tree_cards_quick_add_on_card_show_page'

      assert_project_full_team_member_access_to :controller => 'pages', :action => 'create'
      assert_project_full_team_member_access_to :controller => 'pages', :action => 'edit'
      assert_project_full_team_member_access_to :controller => 'pages', :action => 'update'
      assert_project_full_team_member_access_to :controller => 'pages', :action => 'preview'
      assert_project_full_team_member_access_to :controller => 'pages', :action => 'update_tags'
      assert_project_full_team_member_access_to :controller => 'pages', :action => 'update_favorite_and_tab_status'
      assert_project_full_team_member_access_to :controller => 'pages', :action => 'new'
      assert_project_full_team_member_access_to :controller => 'pages', :action => 'remove_attachment'

      assert_project_full_team_member_access_to :controller => 'cards_import', :action => 'accept'
      assert_project_full_team_member_access_to :controller => 'cards_import', :action => 'display_preview'
      assert_project_full_team_member_access_to :controller => 'cards_import', :action => 'preview'
      assert_project_full_team_member_access_to :controller => 'cards_import', :action => 'import'
      assert_project_full_team_member_access_to :controller => 'cards_import', :action => 'repreview'

      assert_project_full_team_member_access_to :controller => 'favorites', :action => 'remove_team_favorite'

      assert_project_full_team_member_access_to :controller => 'projects', :action => 'remove_attachment'
      assert_project_full_team_member_access_to :controller => 'projects', :action => 'update_tags'

      assert_project_full_team_member_access_to :controller => 'tags', :action => "new"
      assert_project_full_team_member_access_to :controller => 'tags', :action => "edit"
      assert_project_full_team_member_access_to :controller => 'tags', :action => "destroy"
      assert_project_full_team_member_access_to :controller => 'tags', :action => "create"
      assert_project_full_team_member_access_to :controller => 'tags', :action => "update"
      assert_project_full_team_member_access_to :controller => 'tags', :action => "confirm_delete"

      assert_project_full_team_member_access_to :controller => 'transition_executions', :action => "create"
      assert_project_full_team_member_access_to :controller => "murmurs", :action => 'create'
    end
  end

  def test_program_list_should_only_be_accessed_by_authenticated_users
    assert_registered_user_access_to :controller => 'programs', :action => 'index'
  end

  def test_planner_should_not_be_accessed_when_license_is_invalid_and_not_enterprise
    register_license(:max_active_users => 1, :product_edition => Registration::NON_ENTERPRISE) #register an invalid license
    assert_registered_user_cant_access_to :controller => 'plans', :action => 'index'
    assert_registered_user_cant_access_to :controller => 'plans', :action => 'new'
    assert_mingle_admin_cant_access_to :controller => 'plans', :action => 'new'
    assert_mingle_admin_cant_access_to :controller => 'plans', :action => 'index'
  ensure
    reset_license
  end

  def test_planner_should_not_be_accessed_when_license_is_invalid_and_is_enterprise
    register_license(:max_active_users => 1, :product_edition => Registration::ENTERPRISE) #register an invalid license
    assert_mingle_admin_cant_access_to :controller => 'plans', :action => 'index'
    assert_mingle_admin_cant_access_to :controller => 'plans', :action => 'new'
  ensure
    reset_license
  end

  def test_what_actions_does_project_readonly_member_access
    with_first_project do |project|
      @project = project
      assert_project_readonly_member_access_to :controller => 'cards', :action => 'copy'
      assert_project_readonly_member_access_to :controller => 'cards', :action => 'confirm_copy'
      assert_project_readonly_member_access_to :controller => 'cards', :action => 'copy_to_project_selection'
    end
  end

  def test_what_actions_does_project_light_readonly_member_access
    with_first_project do |project|
      @project = project
      assert_project_light_readonly_member_access_to :controller => 'history', :action => 'subscribe'

      assert_project_light_readonly_member_access_to :controller => 'team', :action => 'show_member_email'
      assert_project_light_readonly_member_access_to :controller => 'project_exports', :action => 'confirm_as_project'
      assert_project_light_readonly_member_access_to :controller => 'project_exports', :action => 'confirm_as_template'
      assert_project_light_readonly_member_access_to :controller => 'cards', :action => 'csv_export'
      assert_project_light_readonly_member_access_to :controller => 'projects', :action => 'export'
      assert_project_light_readonly_member_access_to :controller => 'projects', :action => 'show_info'
    end
  end

  def test_what_actions_does_registered_user_access
    with_first_project do |project|
      @project = project
      assert_registered_user_access_to :controller => 'projects', :action => 'request_membership'
    end
  end

  def test_what_actions_does_anonymous_user_access
    User.current = nil
    assert authorized?(:controller => 'profile', :action => 'login')
  end

  def test_oauth_clients_should_only_be_accessible_for_mingle_admins
    OauthClientsController#load controller privileges
    assert_only_mingle_admin_access_to :controller => 'oauth_clients', :action => 'index'
    assert_only_mingle_admin_access_to :controller => 'oauth_clients', :action => 'new'
    assert_only_mingle_admin_access_to :controller => 'oauth_clients', :action => 'update'
    assert_only_mingle_admin_access_to :controller => 'oauth_clients', :action => 'create'
    assert_only_mingle_admin_access_to :controller => 'oauth_clients', :action => 'edit'
    assert_only_mingle_admin_access_to :controller => 'oauth_clients', :action => 'destroy'
    assert_only_mingle_admin_access_to :controller => 'oauth_clients', :action => 'show'
  end

  def test_oauth_user_tokens_should_only_be_accessible_for_non_anonymous_users
    OauthUserTokensController#load controller privileges
    assert_light_user_access_to :controller => 'oauth_user_tokens', :action => 'index'
    assert_light_user_access_to :controller => 'oauth_user_tokens', :action => 'revoke'
    assert_only_mingle_admin_access_to :controller => 'oauth_user_tokens', :action => 'revoke_by_admin'
  end

  def test_oauth_authorize_actions_should_be_accessible_for_registered_users
    assert_light_user_access_to :controller => 'oauth_authorize', :action => 'index'
    assert_light_user_access_to :controller => 'oauth_authorize', :action => 'authorize'
  end

  def test_github_user_cant_access_actions_other_than_github
    github_user = User.create_or_update_system_user(:login => "github", :name => "github",
    :email => "mingle.saas+github@thoughtworks.com",
    :admin => true, :activated => true)

    assert_github_user_cant_access :controller => 'profile', :action => 'login'
    assert_github_user_access_to :controller => 'github', :action => :receive
  end

  private
  def assert_user_privileges(user, privilege_actions, has_privilege)
    login(user)
    privilege_actions.each do |privilege_action|
      privilege_action[:actions].each do |action|
        assert_equal has_privilege, authorized?(controller: privilege_action[:controller], action: action)
      end
    end
  end

end
