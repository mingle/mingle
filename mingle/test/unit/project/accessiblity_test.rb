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

class Project::AccessiblityTest < ActiveSupport::TestCase
  def setup
    @project = with_new_project(:anonymous_accessible => false, :membership_requestable => false) do |project|
      project.add_member(User.find_by_login('member'))
      project.add_member(User.find_by_login('first'))
      project.add_member(User.find_by_login('bob'))
      project.add_member(User.find_by_login('proj_admin'), :project_admin)
    end
    @project.activate
    login_as_admin
  end

  def test_find_membership_requestable_projects_for_user
    @project.update_attribute(:membership_requestable, true)
    assert_include @project, Project.membership_requestable_projects_for(user("longbob"))
  end

  def test_find_membership_requestables_do_not_include_project_that_user_already_memeber_of
    @project.update_attribute(:membership_requestable, true)
    assert_not_include @project, Project.membership_requestable_projects_for(user("member"))
  end

  def test_find_membership_requestable_projects_for_user_without_projects
    @project.update_attribute(:membership_requestable, true)
    assert_include @project, Project.membership_requestable_projects_for(create_user!)
  end

  def test_anonymous_user_do_not_have_membership_requestable_projects
    @project.update_attribute(:membership_requestable, true)
    assert_equal [], Project.membership_requestable_projects_for(User::AnonymousUser.new)
  end

  def test_api_key_user_do_not_have_membership_requestable_projects
    @project.update_attribute(:membership_requestable, true)
    assert_equal [], Project.membership_requestable_projects_for(User::ApiUser.new)
  end

  def test_hidden_project_can_not_be_find_as_membership_requestable
    @project.update_attributes(:hidden => true, :membership_requestable => true)
    assert_not_include @project, Project.membership_requestable_projects_for(user("bob"))
  end

  def test_project_is_accessible_for_its_member
    assert first_project.accessible_for?(user('member'))
    assert !first_project.accessible_for?(user('longbob'))
    assert !first_project.accessible_for?(User::AnonymousUser.new)
  end

  def test_anonymous_accessible_project_is_accessible_for_everyone
    change_license_to_allow_anonymous_access
    set_anonymous_access_for(first_project, true)
    assert first_project.accessible_for?(user('longbob'))
    assert first_project.accessible_for?(User::AnonymousUser.new)
  end

  def test_anonymous_accessible_project_is_only_accessible_for_mingle_admin_when_license_is_invalid
    set_anonymous_access_for(first_project, true)
    clear_license
    assert !first_project.accessible_for?(User::AnonymousUser.new)
    assert !first_project.accessible_for?(user('longbob'))
    assert first_project.accessible_for?(user('member'))
    assert first_project.accessible_for?(user('proj_admin'))
    assert first_project.accessible_for?(user('admin'))
  end

  def test_mingle_admin_can_access_any_project
    assert first_project.accessible_for?(user('admin'))
  end

  def test_project_is_still_accessible_for_memeber_and_admin_after_license_expired
    clear_license
    assert first_project.accessible_for?(user('admin'))
    assert first_project.accessible_for?(user('member'))
  end


  #bug 164
  def test_should_smart_sort_all_anonymous_projects_by_name_and_ignore_case
    project_anony = create_project(:prefix => 'is a anony project', :anonymous_accessible => true)
    project_a = create_project(:prefix => 'a project', :anonymous_accessible => true)
    project_b = create_project(:prefix => 'b project', :anonymous_accessible => true)
    project_C = create_project(:prefix => 'C project', :anonymous_accessible => true)
    project_ascii_before_letters = create_project(:prefix => '! project', :anonymous_accessible => true)
    assert_equal [project_ascii_before_letters.name, project_a.name, project_b.name, project_C.name, project_anony.name], Project.anonymous_accessible_projects.collect(&:name)
  end

  def test_can_tell_whether_has_an_anonymous_accessible_project
    assert ! Project.has_anonymous_accessible_project?
    set_anonymous_access_for(@project, true)
    assert Project.has_anonymous_accessible_project?
  end

  def test_can_get_all_anonymous_accessible_projects
    assert_equal [], Project.anonymous_accessible_projects
    set_anonymous_access_for(@project, true)
    assert_equal [@project], Project.anonymous_accessible_projects
  end

  def test_project_is_requestable_for_non_member
    @project.update_attribute(:membership_requestable, true)
    assert @project.requestable_for?(user('longbob'))
    assert @project.requestable_for?(user('admin'))
    assert !@project.requestable_for?(user('member'))
  end

  def test_project_is_requestable_for_nobody_unless_make_it_requestable
    assert !@project.requestable_for?(user('longbob'))
    assert !@project.requestable_for?(user('admin'))
    assert !@project.requestable_for?(user('member'))
    assert !@project.requestable_for?(User::AnonymousUser.new)
  end

  def test_project_is_requestable_for_nobody_when_license_is_invalid
    @project.update_attribute(:membership_requestable, true)

    clear_license
    assert !@project.requestable_for?(user('longbob'))
    assert !@project.requestable_for?(user('admin'))
    assert !@project.requestable_for?(user('member'))
    assert !@project.requestable_for?(User::AnonymousUser.new)
  end

  def test_project_is_not_requestable_for_anonymous_user
    project = create_project(:name => 'membership requestable', :membership_requestable => true, :users => [user('member')])
    assert !project.requestable_for?(User::AnonymousUser.new)
  end


  #bug 164 (Sort order of project list seems random)
  def test_project_lists_should_order_projects_by_case_ignored_alphabeticly_include_accessible_projects_and_requestable_projects
    change_license_to_allow_anonymous_access
    anonymous_project = create_project(:prefix => 'c project', :anonymous_accessible => true)
    a_project = create_project(:prefix => 'a project')
    a_upper_project = create_project(:prefix => 'A project', :membership_requestable => true)

    b_project = create_project(:prefix => 'b project')
    b_upper_project = create_project(:prefix => 'B project')
    [a_project, b_project, b_upper_project].each do |project|
      project.add_member(user('bob'))
    end
    projects_names = Project.accessible_or_requestables_for(user('bob')).collect(&:name)


    assert projects_names.index(a_project.name) < projects_names.index(b_project.name)
    assert projects_names.index(a_upper_project.name) < projects_names.index(b_project.name)
    assert projects_names.index(b_project.name) < projects_names.index(anonymous_project.name)
    assert projects_names.index(b_upper_project.name) < projects_names.index(anonymous_project.name)
  end

  def test_project_list_should_not_show_duplicates_when_anonymous_project_is_requestable
    @project.update_attributes(:anonymous_accessible => true, :membership_requestable => true)
    assert_equal Project.accessible_or_requestables_for(user('bob')).uniq, Project.accessible_or_requestables_for(user('bob'))
  end


  def test_project_list_should_show_projects_with_auto_enroll_enabled
    user = create_user!
    with_new_project(auto_enroll_user_type: 'full') do |project_with_auto_enroll_enabled|
      login(user)
      accessible_projects = Project.accessible_or_requestables_for(user)
      assert_equal [project_with_auto_enroll_enabled.identifier], accessible_projects.map(&:identifier)
      assert_equal accessible_projects.uniq, accessible_projects
    end
  end

  def test_project_list_should_show_projects_with_auto_enroll_enabled
      autoenroll_all_users(:full,@project)
      accessible_projects = Project.accessible_or_requestables_for(user('bob'))
      assert_equal accessible_projects.uniq, accessible_projects
  end


  def test_should_throw_error_while_trying_to_update_membership_requestable_of_a_template
    with_new_project do |template|
      template.update_attributes(:template => true)
      template.update_attributes(:membership_requestable => true)
      assert_equal ['The request a membership feature is not available for templates.'], template.errors.full_messages
    end
  end

  protected

  def user(login)
    User.find_by_login(login)
  end

end
