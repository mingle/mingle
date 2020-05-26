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

class UserFilterUsageObserverTest < ActiveSupport::TestCase
  
  
  def test_should_increment_filter_usage_when_user_is_the_value_of_a_card_list_view_filter
    member = User.find_by_login('member')
    with_first_project do |project|
      assert_equal 0, member.user_filter_usages.count
      view = CardListView.find_or_construct(project, {:name => 'protex blue', :filters => ["[dev][is][#{member.login}]"]})
      view.save!
      assert_equal 1, member.reload.user_filter_usages.count
      view.favorite.destroy
      assert_equal 0, member.reload.user_filter_usages.count
    end
  end

  def test_should_update_filter_usages_when_the_value_of_a_card_list_view_filter_changes_from_one_user_to_another
    member = User.find_by_login('member')
    bob = User.find_by_login('bob')
    with_first_project do |project|
      view = CardListView.find_or_construct(project, {:name => 'protex blue', :filters => ["[dev][is][#{member.login}]"]})
      view.save!
      assert_equal 1, member.reload.user_filter_usages.count
      assert_equal 0, bob.reload.user_filter_usages.count
      project.card_list_views.create_or_update(:view => {:name => 'protex blue'}, :filters => ["[dev][is][#{bob.login}]"])
      assert_equal 0, member.reload.user_filter_usages.count
      assert_equal 1, bob.reload.user_filter_usages.count
    end
  end
  
  def test_should_update_filter_usages_when_the_value_of_a_card_list_view_filter_changes_from_one_user_to_none
    member = User.find_by_login('member')
    with_first_project do |project|
      view = CardListView.find_or_construct(project, {:name => 'protex blue', :filters => ["[dev][is][#{member.login}]"]})
      view.save!
      assert_equal 1, member.reload.user_filter_usages.count
      project.card_list_views.create_or_update(:view => {:name => 'protex blue'}, :filters => ["[dev][is][]"])
      assert_equal 0, member.reload.user_filter_usages.count
    end
  end

  def test_should_update_filter_usage_when_a_user_is_used_as_a_value_in_card_list_view_mql
    member = User.find_by_login('member')
    with_first_project do |project|
      assert_equal 0, member.user_filter_usages.count
      view = CardListView.find_or_construct(project, {:name => 'white riot', :filters => {:mql => 'dev = member'}})
      view.save!
      assert_equal 1, member.reload.user_filter_usages.count
      view.favorite.destroy
      assert_equal 0, member.reload.user_filter_usages.count
    end
  end
  
  def test_should_update_filter_usage_when_card_list_view_mql_filter_changes_from_one_user_to_another
    member = User.find_by_login('member')
    bob = User.find_by_login('bob')
    with_first_project do |project|
      view = CardListView.find_or_construct(project, {:name => 'protex blue', :filters => {:mql => 'dev = member'}})
      view.save!
      assert_equal 1, member.reload.user_filter_usages.count
      assert_equal 0, bob.reload.user_filter_usages.count
      project.card_list_views.create_or_update(:view => {:name => 'protex blue'}, :filters => {:mql => 'dev = bob'})
      assert_equal 0, member.reload.user_filter_usages.count
      assert_equal 1, bob.reload.user_filter_usages.count
    end
  end
  
  def test_should_update_filter_usage_when_card_list_view_mql_filter_changes_multiple_users
    member = User.find_by_login('member')
    bob = User.find_by_login('bob')
    first = User.find_by_login('first')
    with_first_project do |project|
      view = CardListView.find_or_construct(project, {:name => 'protex blue', :filters => {:mql => 'dev = member OR dev = bob'}})
      view.save!
      assert_equal 1, member.reload.user_filter_usages.count
      assert_equal 1, bob.reload.user_filter_usages.count
      assert_equal 0, first.reload.user_filter_usages.count
      project.card_list_views.create_or_update(:view => {:name => 'protex blue'}, :filters => {:mql => 'dev = first OR dev = bob'})
      assert_equal 0, member.reload.user_filter_usages.count
      assert_equal 1, bob.reload.user_filter_usages.count
      assert_equal 1, first.reload.user_filter_usages.count
    end
  end
  
  def test_should_update_filter_usage_when_user_is_used_as_a_card_list_view_tree_filter
    with_three_level_tree_project do |project|
      member = User.find_by_login('member')
      assert_equal 0, member.user_filter_usages.count
      view = project.card_list_views.create_or_update(:view => {:name => 'whats my name'}, :tf_iteration => ['[owner][is][member]'], :tree_name => project.tree_configurations.first.name)
      assert_equal 1, member.reload.user_filter_usages.count
      view.favorite.destroy
      assert_equal 0, member.reload.user_filter_usages.count
    end
  end

  def test_should_update_filter_usage_when_card_list_view_tree_filters_change_from_one_user_to_another
    with_three_level_tree_project do |project|
      member = User.find_by_login('member')
      bob = User.find_by_login('bob')
      assert_equal 0, member.user_filter_usages.count
      project.card_list_views.create_or_update(:view => {:name => 'janie jones'}, :tf_iteration => ['[owner][is][member]'], :tree_name => project.tree_configurations.first.name)
      assert_equal 1, member.reload.user_filter_usages.count
      project.card_list_views.create_or_update(:view => {:name => 'janie jones'}, :tf_iteration => ['[owner][is][bob]'], :tree_name => project.tree_configurations.first.name)
      assert_equal 0, member.reload.user_filter_usages.count
      assert_equal 1, bob.reload.user_filter_usages.count
    end
  end
  
  def test_should_safely_ignore_filters_on_any_change_to_user_properties
    with_first_project do |project|
      subscription = project.create_history_subscription User.find_by_login('admin'), HistoryFilterParams.new('involved_filter_properties' => {'dev' => '(any change)'}, 'acquired_filter_properties' => {'dev' => '(any change)'}).to_hash      
      assert HistorySubscription.find(subscription.id)
    end
  end
  
  def test_should_update_filter_usage_count_when_subscribing_to_involved_user_property
    new_user = create_user!(:name => 'newguy')
    admin = User.find_by_login('admin')
    with_first_project do |project|
      project.add_member(new_user)
      assert_equal 0, new_user.user_filter_usages.count
      subscription = project.create_history_subscription admin, HistoryFilterParams.new('involved_filter_properties' => {'dev' => new_user.id.to_s}).to_hash
      
      assert_equal 1, new_user.reload.user_filter_usages.count
      subscription.destroy
      assert_equal 0, new_user.reload.user_filter_usages.count
    end    
  end
  
  def test_should_update_filter_usage_count_when_subscribing_to_acquired_user_property
    new_user = create_user!(:name => 'newguy')
    admin = User.find_by_login('admin')
    with_first_project do |project|
      project.add_member(new_user)
      assert_equal 0, new_user.user_filter_usages.count
      subscription = project.create_history_subscription admin, HistoryFilterParams.new('acquired_filter_properties' => {'dev' => new_user.id.to_s}).to_hash
      assert_equal 1, new_user.reload.user_filter_usages.count
      subscription.destroy
      assert_equal 0, new_user.reload.user_filter_usages.count
    end        
  end
  
  def test_filter_usage_count_should_not_change_when_an_unrelated_filter_changes
    new_user = create_user!(:name => 'newguy')
    admin = User.find_by_login('admin')
    with_first_project do |project|
      project.add_member(new_user)
      assert_equal 0, new_user.user_filter_usages.count
      subscription = project.create_history_subscription admin, HistoryFilterParams.new('involved_filter_properties' => {'type' => "new type"}).to_hash
      assert_equal 0, new_user.reload.user_filter_usages.count
    end
  end
  
  def test_filter_usage_count_is_correct_when_using_same_user_property_for_acquired_and_involved_filters
    member = User.find_by_login('member')
    admin = User.find_by_login('admin')
    bob = User.find_by_login('bob')
    with_first_project do |project|
      subscription = project.create_history_subscription admin, HistoryFilterParams.new('acquired_filter_properties' => {'dev' => member.id.to_s}, 'involved_filter_properties' => {'dev' => bob.id.to_s }).to_hash
      assert_equal 1, member.reload.user_filter_usages.count
      assert_equal 1, bob.reload.user_filter_usages.count
      subscription.destroy
      assert_equal 0, member.reload.user_filter_usages.count
      assert_equal 0, bob.reload.user_filter_usages.count
    end        
    
  end

  def test_filter_usage_count_should_increment_when_user_is_used_as_filter_user
    new_user = create_user!(:name => 'newguy')
    admin = User.find_by_login('admin')
    with_first_project do |project|
      project.add_member(new_user)
      assert_equal 0, new_user.user_filter_usages.count
      subscription = project.create_history_subscription admin, HistoryFilterParams.new(:filter_user => new_user.id).to_hash
      assert_equal 1, new_user.reload.user_filter_usages.count
      subscription.destroy
      assert_equal 0, new_user.reload.user_filter_usages.count
    end
  end
  
  
end
