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

class AutoEnrollTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    login_as_admin
  end

  def test_should_include_all_users_as_team_member_when_auto_enroll_user_type_is_set
    autoenroll_all_users('full')
    assert_equal User.count, @project.users.size
  end

  def test_should_include_all_users_as_team_member_when_create_project_with_auto_enroll_user_type
    Project.create!(:identifier => 'id'.uniquify[0..12], :name => 'project', :auto_enroll_user_type => 'full').with_active_project do |project|
      assert_equal User.count, project.users.size
    end
  end

  def test_should_not_include_anonymous_user
    Project.create!(:identifier => 'id'.uniquify[0..12], :name => 'project', :auto_enroll_user_type => 'full').with_active_project do |project|
      assert_false project.member?(User.anonymous)
    end
  end

  def test_should_add_users_as_read_only_member_when_auto_enroll_user_type_is_set_to_readonly
    autoenroll_all_users('readonly') do |_, added_members|
      assert_false added_members.empty?
      assert added_members.all? { |member| @project.readonly_member?(member)  }
    end
  end

  def test_should_not_change_original_users_role_when_auto_enroll_user_type_is_set_to_readonly
    assert @project.users.any?
    @project.users.each { |member| assert_false @project.readonly_member?(member) }
    autoenroll_all_users('readonly') do |original_members, _|
      original_members.each { |member| assert_false @project.readonly_member?(member) }
    end
  end

  def test_should_add_new_user_as_team_member_when_auto_enroll_user_type_is_set
    autoenroll_all_users('full')
    assert_equal User.count, @project.users.size
    create_user!
    assert_equal User.count, @project.reload.users.size
  end

  def test_should_add_new_users_as_readonly_team_member_when_auto_enroll_user_type_is_set_to_readonly
    autoenroll_all_users('readonly')
    assert @project.readonly_member?(create_user!)
  end

  def test_should_be_readonly_member_when_adding_light_user_and_a_project_is_set_auto_enroll_user_type_to_full
    autoenroll_all_users('full')
    assert @project.readonly_member?(create_user!(:light => true))
  end

  def test_should_preserve_old_users_project_admin_privilege_when_auto_enrolling_new_user_as_full_members
    proj_admin = User.find_by_login('proj_admin')
    @project.add_member(proj_admin, :project_admin)

    autoenroll_all_users('full')
    @project.project_admin?(proj_admin)
  end

  def test_should_preserve_old_users_readonly_privilege_when_auto_enrolling_new_user_as_full_members
    readonly = User.find_by_login('read_only_user')
    @project.add_member(readonly, :readonly_member)
    autoenroll_all_users('full')
    assert @project.readonly_member?(readonly)
  end

  def test_team_members_are_not_removable_after_project_is_set_auto_enroll_user_type
    autoenroll_all_users('full')
    @project.reload

    @project.users.each do |member|
      assert_false @project.team.validate_for_removal(member).empty?
    end
  end

  def test_should_not_change_team_members_status_when_disable_auto_enroll_user_type_option_from_full
    autoenroll_all_users('full')
    turn_off_autoenroll do |original_members, _|
      assert_equal original_members.sort_by(&:id), @project.users.sort_by(&:id)
    end
  end

  def test_should_not_change_team_members_status_when_disable_auto_enroll_user_type_option_from_readonly
    autoenroll_all_users('readonly')
    turn_off_autoenroll do |original_members, _|
      assert_equal original_members.sort_by(&:id), @project.users.sort_by(&:id)
    end
  end

  def test_member_should_be_removable_after_disabled_auto_enroll_user_type_option
    autoenroll_all_users('readonly')
    turn_off_autoenroll
    ThreadLocalCache.clear!
    @project.users.reload.clear
    assert_equal [], @project.users.reload.to_a
  end

  def test_auto_enroll_user_type_should_be_able_to_export_and_import
    with_new_project do |project|
      autoenroll_all_users('readonly', project)
      project_member_names = project.users.collect(&:name)
      export_file = create_project_exporter!(project, User.current).export
      create_project_importer!(User.current, export_file).process!.reload.with_active_project do |imported_project|
        assert_equal 'readonly', imported_project.auto_enroll_user_type
        assert_sort_equal project_member_names, imported_project.users.collect(&:name)
      end
    end
  end

  def test_new_users_imported_should_be_members_of_project_enabled_enroll_users_as_members
    bob = create_user! :name => 'foo', :login => 'foo'
    with_new_project do |project|
      project.add_member(bob)

      export_file = create_project_exporter!(project, User.current).export

      project.remove_member(bob)
      bob.destroy

      autoenroll_all_users('readonly', project)
      #bob should be created again during importing
      create_project_importer!(User.current, export_file).process!

      project.reload
      assert_include 'bob', project.users.collect(&:login)
    end
  end

  def test_reset_auto_enrolled_projects
    autoenroll_all_users('readonly')
    Project.reset_auto_erolled_projects
    assert_false @project.reload.auto_enroll_enabled?
  end
end
