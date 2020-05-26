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

class DeleteOrphanUsersTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @user1, @user2, @user3 = [sample_user('user1'), sample_user('user2'), sample_user('user3')]
    [@user1, @user2, @user3].each{ |u| assert u.save(false) }
  end

  def test_should_delete_users_not_in_any_project
    first_project.add_member(@user1)
    User.delete_orphan_users

    assert_record_deleted @user1
    assert_record_deleted @user2
    assert_record_deleted @user3
  end

  def test_should_know_deletable_users
    deletable_users = User.all.select(&:deletable?).sort_by(&:login) - [User.current]
    assert_equal deletable_users.sort_by(&:id), User.deletable_users.sort_by(&:id)
  end

  def test_team_member_without_project_data_should_deletable
    with_three_level_tree_project do |project|
      project.add_member(@user2)
      assert !@user2.has_project_data?
      assert @user2.deletable?
      assert @user2.destroy
      assert_record_deleted @user2
    end
  end

  def test_team_member_with_no_project_data_and_in_a_group_is_deleted_cleanly
    with_first_project do |project|
      project.add_member(@user1)
      group = project.groups.create(:name => 'unimportant team members')
      group.add_member(@user1)
      group.save!
      assert @user1.destroy
      assert_equal 0, group.reload.users.count
    end
  end

  def test_team_member_in_auto_enroll_project_with_no_project_data_is_deleted_cleanly
    with_first_project do |project|
      auto_enrolled_user = create_user!(:login => 'i_am_autoenrolled')
      project.update_attribute(:auto_enroll_user_type, 'full')
      assert project.member?(auto_enrolled_user)
      assert_false project.team.member?(auto_enrolled_user)
      project.add_member(auto_enrolled_user, :project_admin)
      assert project.team.member?(auto_enrolled_user)

      assert_equal 1, MemberRole.count(:all, :conditions => { :member_id => auto_enrolled_user.id, :deliverable_id => project.id })
      auto_enrolled_user.destroy
      assert_false project.member?(auto_enrolled_user)
      assert_equal 0, MemberRole.count(:all, :conditions => { :member_id => auto_enrolled_user.id, :deliverable_id => project.id })
    end
  end

  def test_team_member_with_project_data_should_not_be_deletable
    with_three_level_tree_project do |project|
      project.add_member(@user2)
      create_plv!(project, :name => 'My Favorite Team Member', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @user2.id.to_s)
      assert !@user2.deletable?
    end
  end

  def test_should_know_if_a_team_member_has_no_project_data
    with_three_level_tree_project do |project|
      project.add_member(@user2)
      assert !@user2.has_project_data?
    end
  end

  def test_should_know_if_user_is_used_in_plv
    with_three_level_tree_project do |project|
      project.add_member(@user2)
      create_plv!(project, :name => 'Unrelated PLV', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @user2.id.to_s)
    end
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      create_plv!(project, :name => 'My Favorite Team Member', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @user1.id.to_s)
      ThreadLocalCache.clear!
      assert @user1.has_project_data?
    end
  end

  def test_should_know_if_user_is_used_in_transition_action
    with_three_level_tree_project do |project|
      project.add_member(@user2)
      transition = create_transition(project, 'another user', :set_properties => {:owner => @user2.id})
    end

    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      transition = create_transition(project, 'set to member', :set_properties => {:dev => @user1.id})
      ThreadLocalCache.clear!
      assert @user1.has_project_data?
    end
  end

  def test_should_know_if_user_is_assigned_to_a_transition
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      transition = create_transition(project, 'you must be user1 to execute', :set_properties => {:priority => 'Low'}, :user_prerequisites => [@user1.id])
      assert_equal 1, transition.prerequisites.size
      ThreadLocalCache.clear!
      assert @user1.has_project_data?
    end
  end

  def test_should_know_if_user_is_part_of_a_transition_prerequisite
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      transition = create_transition(project, 'dev must be user1', :required_properties => {:dev => @user1.id}, :set_properties => {:status => 'closed'})
      assert_equal 1, transition.prerequisites.size
      ThreadLocalCache.clear!
      assert @user1.has_project_data?
    end
  end

  def test_should_know_if_user_is_a_card_default
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      card_type = project.card_types.first

      card_defaults = card_type.card_defaults
      card_defaults.update_properties :dev => @user1.id
      card_defaults.save!
      ThreadLocalCache.clear!

      assert @user1.has_project_data?
    end
  end

  def test_should_know_if_user_is_used_in_a_card_list_view_filter
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      CardListView.find_or_construct(project, {:name => 'protex blue', :filters => ["[dev][is][#{@user1.login}]"]}).save!
      ThreadLocalCache.clear!
      assert @user1.reload.has_project_data?
    end
  end

  def test_should_be_able_to_cleanly_delete_user_with_no_project_data_who_owns_personal_favorites
    with_first_project do |project|
      project.add_member(@user1)
      CardListView.find_or_construct(project, {:name => 'big bug shuffle', :filters => ["[dev][is][(not set)]"], :user_id => @user1.id}).save!
    end
    @user1.destroy
    assert_nil User.find_by_login(@user1.login)
  end

  def test_should_know_if_user_is_used_as_the_filter_user_in_history_subscription
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      project.create_history_subscription User.find_by_login('admin'), HistoryFilterParams.new(:filter_user => @user1.id).to_hash
      ThreadLocalCache.clear!
      assert @user1.reload.has_project_data?
    end
  end

  def test_should_know_if_user_is_used_as_acquired_property_in_history_subscription
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      project.create_history_subscription User.find_by_login('admin'), HistoryFilterParams.new('acquired_filter_properties' => { 'dev' => @user1.id.to_s}).to_hash
      ThreadLocalCache.clear!
      assert @user1.reload.has_project_data?
    end
  end

  def test_should_know_if_user_has_a_subscription
    with_first_project do |project|
      project.add_member(@user1)
      assert !@user1.has_project_data?
      project.create_history_subscription @user1, HistoryFilterParams.new(:filter_user => @user2.id).to_hash
      ThreadLocalCache.clear!
      assert @user1.reload.has_project_data?
    end
  end

  def test_should_not_delete_mingle_admin
    @user1.admin = true
    @user1.save(false)

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_should_not_delete_user_who_has_created_murmurs
    with_first_project do |project|
      create_murmur(:author => @user1)
    end

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_should_not_delete_user_who_has_created_page
    login @user1.email
    with_first_project do |project|
      project.pages.create!(:name => "from user1")
    end

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_should_not_delete_user_who_has_modified_page
    with_first_project do |project|
      login_as_member
      page = project.pages.create!(:name => "page")

      login @user1.email
      page.update_attribute(:name, "new page")
    end

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_should_not_delete_user_who_has_modified_page_in_history
    with_first_project do |project|
      login_as_member
      page = project.pages.create!(:name => "page")
      login @user1.email
      page.update_attribute(:name, "new page")
      login_as_member
      page.update_attribute(:name, "page")
    end

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_should_not_delete_user_who_has_modified_card

    with_first_project do |project|
      login_as_member
      card = create_card!(:name => "from user1")

      login @user1.email
      card.update_attribute(:name, 'new name')
    end

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_should_not_delete_user_who_has_created_card
    login @user1.email
    with_first_project do |project|
      create_card!(:name => "from user1")
    end

    login @user2.email
    with_project_without_cards do |project|
      card = create_card!(:name => 'from user2')
    end

    User.delete_orphan_users
    assert_record_not_deleted @user1
    assert_record_not_deleted @user2
  end

  def test_should_not_delete_user_who_has_modified_card_in_history
    with_first_project do |project|
      login_as_member
      card = create_card!(:name => 'a card')
      login @user1.email
      card.update_attribute(:name, "new card")
      login_as_member
      card.update_attribute(:name, "a card again")
    end

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_should_not_delete_user_who_is_used_as_value_of_user_property_definition_on_card
    with_first_project do |project|
      login_as_member
      card = create_card!(:name => 'a card')
      card.update_attribute(:cp_dev, @user1)
    end

    with_project_without_cards do |project|
      login_as_member
      card = create_card!(:name => 'a card')
      card.update_attribute(:cp_dev, @user2)
    end

    User.delete_orphan_users
    assert_record_not_deleted @user1
    assert_record_not_deleted @user2
    assert_record_deleted @user3
  end

  def test_should_not_delete_user_who_is_used_as_value_of_user_property_definition_on_card_version
    with_first_project do |project|
      login_as_member
      card = create_card!(:name => 'a card')
      card.update_attribute(:cp_dev, @user1)
      card.update_attribute(:cp_dev, nil)
    end

    User.delete_orphan_users
    assert_user23_deleted_but_not_user1
  end

  def test_non_project_related_user_should_be_deletable
    assert @user1.deletable?
  end

  def test_non_project_related_admin_should_be_deletable
    @user1.admin = true
    @user1.save!
    assert @user1.deletable?
  end

  def test_projects_currently_being_imported_should_not_be_included_in_deletable_check
    with_first_project do |project|
      login_as_member
      card = create_card!(:name => 'a card')
      card.update_attribute(:cp_dev, @user1)
    end

    with_project_without_cards do |project|
      project.hidden = true      # this suggests that project is currently importing
      project.save!
      login_as_member
      card = create_card!(:name => 'a card')
      card.update_attribute(:cp_dev, @user2)
    end

    assert !@user1.deletable?
    assert @user2.deletable?
  end

  def test_should_not_delete_user_if_user_has_created_objective
    program = program('simple_program')
    program.add_member(@user1)
    program.add_member(@user2)
    login @user1.email
    program.objectives.planned.create(:name => 'first', :start_at => '2011-1-1', :end_at => '2011-2-1')

    login_as_admin

    assert !@user1.deletable?
    assert @user2.deletable?
  end

  def test_should_not_delete_user_if_user_has_modified_objective
    program = program('simple_program')
    program.add_member(@user1)
    objective = program.objectives.planned.create(:name => 'first', :start_at => '2011-1-1', :end_at => '2011-2-1')
    login @user1.email
    objective.update_attributes(:name => 'changed_name')

    login_as_admin

    assert !@user1.deletable?
    assert @user2.deletable?
    assert @user3.deletable?
  end

  def test_should_not_delete_user_if_user_has_created_any_dependency
    with_first_project do |project|
      project.add_member(@user1)
      project.add_member(@user2)
      project.add_member(@user3)
      login_as_member
      card = create_card!(:name => 'a card')
      login @user1.email
      dependency = card.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => project.id)
      dependency.save!
      login_as_member
    end
    assert !@user1.deletable?
    assert @user2.deletable?
    assert @user3.deletable?

  end

  def sample_user(name)
    User.new(:name => name, :login => name, :email => "#{name}@domain.com")
  end

  def assert_user23_deleted_but_not_user1
    assert_record_not_deleted @user1, "user1 should not have been deleted but was"
    assert_record_deleted @user2, "user2 should have been deleted but was not"
    assert_record_deleted @user3, "user3 should have been deleted but was not"
  end


end
