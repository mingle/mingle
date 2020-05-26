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

# Tags: user, favorites
class UserSearchTest < ActiveSupport::TestCase

  def teardown
    cleanup_repository_drivers_on_failure
    Authenticator.password_format = :strict
    reset_license
    super
  end

  def test_should_return_25_users_in_result
    increase_user_numbers_to 30
    assert_equal 25, User.search(nil, 1).size
  end

  def test_search_user_should_order_by_name_as_default
    assert_equal User.find(:all).collect(&:name).sort[0..24], User.search(nil, 1).collect(&:name)
  end

  def test_query_count_of_search_result
    assert_equal 0, User.search_count("users")

    users = (1..6).map do |index|
      create_user!(:name => "users" << index.to_s)
    end

    assert_equal 6, User.search_count("users")
    users.first.update_attributes(:activated => false)
    assert_equal 5, User.search_count("users", :exclude_deactivated_users => true)
  end

  def test_most_recently_logined_user_should_come_last_when_order_by_last_login_descending
    bob = User.find_by_login('bob')
    admin = User.find_by_login('admin')
    bob.login_access.update_attribute(:last_login_at, 10.minutes.ago)
    admin.login_access.update_attribute(:last_login_at, Time.now)
    results = User.search(nil, 1, :order_by => "last_login_at", :direction => :desc)
    assert (results.index(admin) > results.index(bob))
  end

  def test_most_recently_logined_user_should_come_first_when_order_by_last_login_ascending
    bob = User.find_by_login('bob')
    admin = User.find_by_login('admin')
    bob.login_access.update_attribute(:last_login_at, 10.minutes.ago)
    admin.login_access.update_attribute(:last_login_at, Time.now)
    results = User.search(nil, 1, :order_by => "last_login_at", :direction => :asc)
    assert (results.index(admin) < results.index(bob))
  end

  def test_order_by_email_descending
    assert_equal User.find(:all).collect(&:email).sort[0..24].reverse, User.search(nil, 1, :order_by => "email", :direction => :desc).map(&:email)
  end

  def test_order_by_activated_ascending
    bob = User.find_by_login('bob')
    bob.update_attribute(:activated, false)
    longbob = User.find_by_login('longbob')
    longbob.update_attribute(:activated, false)
    results = User.search(nil, 1, :order_by => 'activated', :direction => :asc)
    assert_equal bob, results.first
    assert_equal longbob, results.second
    assert_equal User.find(:all).collect(&:activated).collect(&:to_s).sort[0..24], results.map(&:activated).map(&:to_s)
  end

  def test_secondary_sort_is_name
    #all users have never logged in
    User.all.each do |u|
      u.login_access.update_attribute(:last_login_at, nil)
    end

    results = User.search(nil, 1, :order_by => "last_login_at", :direction => :asc)

    assert_equal User.find(:all).collect(&:name).sort[0..24], results.map(&:name)
  end

  def test_should_only_show_first_25_users_in_result_when_page_is_wrong
    increase_user_numbers_to 30
    assert_equal 25, User.search(nil, '-1').size
    assert_equal 5, User.search(nil, '6').size
    assert_equal 25, User.search(nil, 'a').size
  end

  def test_set_per_page
    increase_user_numbers_to 30
    assert_equal 29, User.search(nil, 1, :per_page => '29').size
    assert_equal 1, User.search(nil, 2, :per_page => '29').size
  end

  def test_should_search_users_by_name
    user1 = create_user!(:name => 'phoenix')
    user2 = create_user!(:name => 'phoenixtoday')

    assert_equal ['phoenix', 'phoenixtoday'], search_user_by_default_page('phoenix').collect(&:name).sort
  end

  def test_should_search_users_by_login
    increase_user_numbers_to 30
    user1 = create_user!(:login => 'phoenix')
    user2 = create_user!(:login => 'phoenixtoday')

    assert_equal 2, search_user_by_default_page('phoenix').size
  end

  def test_search_user_should_allow_put_containing_space_in_search_query_boundary
    user1 = create_user!(:login => 'phoenix')
    user2 = create_user!(:login => 'phoenixtoday')

    assert_equal 2, search_user_by_default_page('  phoenix').size
    assert_equal 2, search_user_by_default_page('phoenix  ').size
  end

  def test_should_search_users_by_email
    increase_user_numbers_to 30
    user1 = create_user!(:login => 'phoenix@email.com')
    user2 = create_user!(:login => 'phoenixtoday@email.com')

    assert_equal 2, search_user_by_default_page('phoenix').size
  end

  def test_should_search_users_by_version_control_user_name
    increase_user_numbers_to 30
    user1 = create_user!(:version_control_user_name => 'phoenix')
    user2 = create_user!(:version_control_user_name => 'phoenixtoday')

    assert_equal 2, search_user_by_default_page('phoenix').size
  end

  def test_should_not_match_any_thing_when_search_query_result_nothing
    increase_user_numbers_to 30
    user1 = create_user!(:version_control_user_name => 'phoenix')
    user2 = create_user!(:version_control_user_name => 'phoenixtoday')

    assert_equal 0, search_user_by_default_page('phEOnix').size
  end

  def test_user_search_results_order_should_not_be_case_sensitive
    uniquified = 'aaaaa'.uniquify[0..8]
    ["#{uniquified}bc", "#{uniquified}Bc", "#{uniquified}cc"].each { |name| create_user!(:name => name) }

    assert_equal "#{uniquified}cc", search_user_by_default_page('aaaaa').collect(&:name).last
  end

  def test_user_search_results_can_be_restricted_to_a_team
    unique_name = 'zzz'.uniquify
    team_member = create_user!(:name => "#{unique_name}member")
    non_team_member = create_user!(:name => "#{unique_name}nonmember")
    with_first_project do |project|
      project.add_member(team_member)
      assert_equal [team_member], project.users.search(unique_name, 1)
    end
  end

  def test_order_should_be_case_insensitive
    uniquified = 'aaaaa'.uniquify[0..8]
    ordered_user_names = ["#{uniquified}bc", "#{uniquified}Bc", "#{uniquified}cc"]
    ordered_user_names.each { |name| create_user!(:name => name) }
    assert_equal "#{uniquified}cc", User.search('aaaaa', nil, :order_by => 'name', :direction => 'asc').collect(&:name).last
  end

  def test_direction_accepts_only_valid_directions
    assert_equal("LOWER(name) asc, LOWER(#{User.quoted_table_name}.name)", User.send(:order_by_clause_for_search, 'name', 'asc'))
    assert_equal("LOWER(name) asc, LOWER(#{User.quoted_table_name}.name)", User.send(:order_by_clause_for_search, 'name', 'Select admin'))
  end

  private
  def search_user_by_default_page(search_query)
    User.search(search_query, nil)
  end

  def nil_safe_compare(a, b)
    return a <=> b unless (a.nil? || b.nil?)
    return 1 if a.nil?
    -1
  end
end
