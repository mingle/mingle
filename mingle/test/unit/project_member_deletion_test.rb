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

#Tags:
class ProjectMemberDeletionTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @member = User.find_by_login('member')
    @project.activate
    login_as_admin
  end

  def test_project_admin_can_not_remove_self_from_team
    proj_admin = User.find_by_login('proj_admin')
    login(proj_admin.email)

    assert_false @project.remove_member(proj_admin)
    @project.reload
    assert @project.member?(proj_admin)
  end

  def test_mingle_admin_can_remove_self_from_team
    admin = User.find_by_login('admin')
    @project.add_member(admin, :project_admin)
    assert @project.remove_member(admin)
    @project.reload
    assert_false @project.member?(admin)
  end

  def test_should_remove_project_member_from_groups_when_deleted
    user = create_user!(:light =>  true)
    group = @project.user_defined_groups.create!(:name => "Developers")
    @project.add_member(user)
    group.add_member(user)

    @project.remove_member(user)

    assert_false @project.member?(user)
    group.reload
    assert_false group.member?(user)
  end

  # bug 2906, scenario 1 action.
  def test_transition_that_only_sets_a_property_to_member_should_be_removed_along_with_member
    transition = create_transition(@project, 'remove owner', :set_properties => {:dev => @member.id})
    destroy_membership(@member)
    assert_record_deleted transition
  end

  def test_should_set_card_default_user_property_value_to_not_set_if_team_member_who_is_set_as_user_property_default_is_removed
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    card_defaults.update_properties :dev => @member.id
    card_defaults.save!

    destroy_membership(@member)

    assert_nil card_type.reload.card_defaults.property_value_for('dev')
  end

  def test_should_set_user_property_value_to_not_set_if_remove_team_member_who_is_set_as_user_property_value
    card1 = create_card!(:name => 'card1', :dev => @member.id)
    destroy_membership(@member)
    assert_nil card1.reload.cp_dev
  end

  def test_should_destroy_subscriptions_when_user_is_removed_from_project_membership
    card_1 = @project.cards.first
    subscription_1 = @project.create_history_subscription(@member, "card_number=#{card_1.number}")
    destroy_membership(@member)
    assert_equal [], @project.reload.history_subscriptions
  end

  def test_remove_member_should_delete_his_personal_favorites
    @view = @project.card_list_views.create_or_update(:view => {:name => 'view1'}, :style => 'list', :user_id => @member.id)
    destroy_membership(@member)
    assert_equal [], @member.personal_views_for(@project)
  end

  def test_should_only_remove_target_project_personal_favorites
    project_one = with_new_project do |project|
      project.add_member(@member)
      project.card_list_views.create_or_update(:view => {:name => 'view1'}, :style => 'list', :user_id => @member.id)
    end

    with_new_project do |project|
      project.add_member(@member)
      @view2 = project.card_list_views.create_or_update(:view => {:name => 'view2'}, :style => 'list', :user_id => @member.id)
    end

    destroy_membership(@member, project_one)
    assert_equal [@view2], @member.personal_views
  end

  def test_personal_views_should_include_all_views_when_user_is_mingle_admin_and_project_readonly
    member = login_as_admin
    with_new_project do |project|
      project.add_member(member)
      @view1 = project.card_list_views.create_or_update(:view => {:name => 'view1'}, :style => 'list', :user_id => member.id)
      project.add_member(member, :readonly_member)
    end
    assert_equal [@view1.name], member.personal_views.collect(&:name)
  end

  def test_personal_views_should_not_be_deleted_when_mingle_admin_membership_is_removed
    member = login_as_admin
    with_new_project do |project|
      project.add_member(member)
      @view1 = project.card_list_views.create_or_update(:view => {:name => 'view1'}, :style => 'list', :user_id => member.id)
      project.remove_member(member)
    end
    assert_equal [@view1.name], member.personal_views.collect(&:name)
  end

  def test_card_defaults_usages
    deletion = ProjectMemberDeletion.
               for_direct_member(@project, @member)
    assert deletion.card_defaults_usages.empty?
    assert_difference "ProjectMemberDeletion.for_direct_member(@project, @member).card_defaults_usages.size", 1 do
      @project.card_types.first.card_defaults.update_properties :dev => @member.id
    end
  end

  def test_property_usages
    assert_difference "ProjectMemberDeletion.for_direct_member(@project, @member).property_usages.size", 1 do
      create_card!(:name => 'card 1', :dev => @member.id, :card_type => 'Card')
    end
  end

  def test_property_usages_should_not_include_card_defaults_usages
    assert_no_difference "ProjectMemberDeletion.for_direct_member(@project, @member).property_usages.size" do
      @project.card_types.first.card_defaults.update_properties :dev => @member.id
    end
  end

  def test_deleting_a_user_membership_deletes_associated_members_roles
    destroy_membership(@member)
    assert_nil @project.member_roles.find_by_member(@member)
  end

  def destroy_membership(member, project=@project)
    ProjectMemberDeletion.for_direct_member(project, member).execute
    project.reload
  end

end
