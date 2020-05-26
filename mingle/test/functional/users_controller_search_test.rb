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

class UsersControllerSearchTest < ActionController::TestCase

  def setup
    @controller = create_controller UsersController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
  end

  def test_should_paginate_user_list
    increase_user_numbers_to 30
    get :list
    assert_user_first_page
  end

  def test_should_show_25_users_per_page
    increase_user_numbers_to 30
    get :list
    assert_equal 25, assigns['users'].size
  end

  def test_paginate_can_list_specific_pages
    increase_user_numbers_to 30
    get :list, :page => 2
    assert_equal 5, assigns['users'].size
    assert_select "span.disabled.next_page", :text => 'Next'
    assert_select "a.prev_page", :html => 'Previous'
  end

  def test_should_show_user_count_number_in_card_list_page
    increase_user_numbers_to 30
    get :list, :page => 2
    assert_select 'div.pagination-summary', :text => 'Viewing 26 - 30 of 30 users'

    increase_user_numbers_to 60
    get :list, :page => 2
    assert_select 'div.pagination-summary', :text => 'Viewing 26 - 50 of 60 users'
  end

  def test_should_show_message_correctly_when_searching
    increase_user_numbers_to 30
    user1 = create_user!(:name => 'phoenix')
    user2 = create_user!(:name => 'phoenixtoday')

    get :list, :search => { :query => 'phoenix' }

    assert_equal "Search results for #{'phoenix'.bold}.", flash[:info]
    assert_select 'div.pagination-summary', :text => 'Viewing 1 - 2 of 2 users'
  end

  def test_should_not_show_search_result_message_when_not_using_search
    increase_user_numbers_to 30
    get :list
    assert_select 'div.pagination-summary', :text => 'Viewing 1 - 25 of 30 users'
  end

  def test_should_show_no_result_info_message_when_searched_for_no_result
    get :list, :search => { :query => 'phoenix' }
    assert_response :success
    assert_template 'list'
    assert_equal "Your search for #{'phoenix'.bold} did not match any users.", flash[:info]
    assert_select 'div#pagination-info', false
  end

  def test_should_show_page_one_if_page_params_is_invalid
    increase_user_numbers_to 30
    get :list, :page => -1
    assert_user_first_page
  end

  def test_should_show_search_form_on_user_list_page
    get :list
    assert_select 'form#user-search'
    assert_select '#user-search-submit'
    assert_select '#search-query'
  end

  def test_should_show_link_to_cancel_search_when_you_have_actually_searched_for_something
    get :list
    assert_select '#search-all-users', :count => 0

    get :list, :search => {:query => 'a'}
    assert_select '#search-all-users', :count => 1
  end

  def test_should_show_search_result
    increase_user_numbers_to 30
    user1 = create_user!(:name => 'phoenix')
    user2 = create_user!(:name => 'phoenixtoday')

    get :list, :search => { :query => 'phoenix' }
    assert_select "#user_#{user1.id}"
    assert_select "#user_#{user2.id}"
  end

  def test_should_search_for_activated_or_deactived_users_should_rely_on_show_deactived_user_preference
    activated_user = create_user!(:name => 'phoenix')
    deactivated_user = create_user!(:name => 'phoenixtoday', :activated => false)
    UserDisplayPreference.current_user_prefs.update_preference(:show_deactived_users, false)
    User.current.reload
    get :list, :search => { :query => 'phoenix' }
    assert_select "#user_#{activated_user.id}"
    assert_select "#user_#{deactivated_user.id}", :count => 0

    UserDisplayPreference.current_user_prefs.update_preference(:show_deactived_users, true)
    User.current.reload
    get :list, :search => { :query => 'phoenix' }
    assert_select "#user_#{activated_user.id}"
    assert_select "#user_#{deactivated_user.id}"
  end

  def assert_user_first_page
    assert_select "a.next_page", :html => 'Next'
    assert_select "span.disabled.prev_page", :text => 'Previous'
  end

  def test_should_order_by_name_asc_by_default
    get :list
    assert_select "#name.asc"
  end

  def test_should_be_able_to_specify_order_by_and_direction
    get :list, :search => {:order_by => 'login', :direction => 'DESC'}
    assert_select "#login.desc"
  end
end
