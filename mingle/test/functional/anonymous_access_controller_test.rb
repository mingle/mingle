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

require File.expand_path(File.dirname(__FILE__) + '/../functional_test_helper')

class AnonymousAccessControllerTest < ActionController::TestCase

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = create_controller(ProjectsController, :own_rescue_action => true)
    @project = first_project
    set_anonymous_access_for(@project, true)
    logout_as_nil
    change_license_to_allow_anonymous_access
  end

  def teardown
    set_anonymous_access_for(@project, false)
    reset_license
  end

  def test_anonymous_user_can_see_overview_of_anonymous_project
    assert User.current.anonymous?
    get :overview, :project_id => @project.identifier
    assert_response :success
    assert_template 'overview'
  end

  def test_authenticated_user_should_still_using_there_own_access
    login_as_admin
    get :overview, :project_id => @project.identifier
    assert_response :success
    assert_equal User.find_by_login('admin'), User.current
  end

  def test_anonymous_user_can_do_ajax_call
    assert User.current.anonymous?
    @controller = create_controller CardsController
    xhr :get, :list, :project_id => @project.identifier
    assert_response :success
  end

  def test_anonymous_user_should_store_their_display_perference_in_session
    @controller = create_controller UserDisplayPreferenceController
    xhr :post, :update_user_display_preference, :project_id => @project.identifier, :user_display_preference => {"excel_import_export_visible" => "false"}
    assert_response :success
    assert_equal 'false', @request.session['user_display_preference']["excel_import_export_visible"]
  end

  def test_should_not_show_email_address_to_anonymous_user
    @controller = create_controller TeamController
    get :list, :project_id => @project.identifier
    assert_select 'td.email', {:count => 0, :text => User.find_by_login('bob').email}
    assert_select 'th', {:count => 0, :text => 'Email'}
  end

  def test_should_still_show_email_address_to_non_memeber_user_who_is_a_registered_user
    login_as_longbob
    @controller = create_controller TeamController
    get :list, :project_id => @project.identifier
    assert_select 'td.email', {:count => 1, :text => User.find_by_login('bob').email}
    assert_select 'th', {:count => 1, :text => 'Email'}
  end

  def test_should_not_show_excel_export_to_anonymous_user
    @controller = create_controller CardsController
    get :list, :project_id => @project.identifier
    assert_select 'div#collapsible-section-for-Import---Export', false
  end

  def test_should_not_show_export_project_link_to_anonymous_user
    @controller = create_controller PagesController
    get :list, :project_id => @project.identifier
    assert_select 'a', {:count=>0, :text=>"Export project"}
    assert_select 'a', {:count=>0, :text=>"Export project as template"}
  end

  def test_should_show_login_link_instead_of_profile_for_anonymous_user
    @controller = create_controller PagesController
    get :list, :project_id => @project.identifier
    assert_select 'a.sign-in', true
    assert_select 'a.profile', false
  end

  def test_without_anonymous_access_project_project_list_should_redirect_user_to_login
    set_anonymous_access_for(@project, false)
    get :list
    assert_response :redirect
  end

  def test_should_show_all_anonymous_projects_to_anonymous_user
    with_new_project do |project|
      set_anonymous_access_for(project, true)
      @project = project
      assert_can_see_anonymous_project_on_projects_list
    end
  end

  def test_registered_user_should_see_anonymous_accessible_projects_on_project_list
    with_new_project do |project|
      set_anonymous_access_for(project, true)
      @project = project
      login_as_longbob
      assert_can_see_anonymous_project_on_projects_list
    end
  end

  def test_anonymous_user_should_not_be_able_to_subscribe_project_history_via_email
    assert_subscribe_via_email_link_count 0
    assert_already_subscribed_link_count 0
    assert_select 'p.email-disabled', {:count => 0}
    assert_can_not_subscribe_by_email_using_url
  end

  def test_registered_user_should_not_be_able_to_subscribe_to_email_of_projects_they_are_not_a_member_of
    login_as_longbob
    assert_subscribe_via_email_link_count 0
    assert_already_subscribed_link_count 0
    assert_select 'p.email-disabled', {:count => 0}
    assert_can_not_subscribe_by_email_using_url
  end

  def test_readonly_member_can_subscribe_via_email
    member = login_as_member
    @project.add_member(member, :readonly_member)
    User.current.reload
    assert_subscribe_via_email_link_count 1
  end

  def test_current_user_in_filter_should_not_match_anything_for_anonymous_user
    @controller = create_controller CardsController
    login_as_member
    @project.with_active_project do
      @project.cards.each{ |c| c.update_attribute(:cp_dev_user_id, User.current.id) }
      @project.cards.find_by_name('first card').update_attribute(:cp_dev_user_id, nil)
    end

    get :list, :style => 'list', :project_id => @project.identifier, :filters => ['[dev][is][(current user)]', '[TyPe][iS][CaRd]']
    assert !assigns['cards'].empty?
    logout_as_nil
    get :list, :style => 'list', :project_id => @project.identifier, :filters => ['[dev][is][(current user)]', '[TyPe][iS][CaRd]']

    assert_equal [], assigns['cards']
    get :list, :style => 'list', :project_id => @project.identifier, :filters => ['[dev][is not][(current user)]', '[TyPe][iS][CaRd]']
    assert_equal @project.cards.size, assigns['cards'].size
  end

  def test_anonymous_user_should_see_simple_feed_url_instead_of_encrypted
    @controller = create_controller HistoryController
    get :index, :project_id => @project.identifier
    each_element 'a.rss' do |el|
      assert_equal "http://test.host/projects/#{@project.identifier}/feeds.atom", el.attributes['href']
    end
  end

  def test_should_shutdown_anonymous_access_to_plain_feed_with_project_anonymous_accessiblity_turning_off
    set_anonymous_access_for(@project, false)
    @controller = create_controller(HistoryController)
    get :plain_feed, :format => "atom", :project_id => @project.identifier, :acquired_filter_tags => ['first_tag']
    assert_response 401
    login_as_longbob
    assert_raise ErrorHandler::UserAccessAuthorizationError do
      get :plain_feed, :format => "atom", :project_id => @project.identifier, :acquired_filter_tags => ['first_tag']
    end
  end

  def test_should_allow_anonymous_user_to_see_about_page
    @controller = create_controller(AboutController)
    get :index
    assert_response :success
  end

  def test_should_redirect_anonymous_user_to_login_url_when_they_cant_access_to_it
    set_anonymous_access_for(@project, true)
    @controller = create_controller(CardsController, :own_rescue_action => true)
    get :list, :project_id => @project.identifier
    assert_response :success

    set_anonymous_access_for(@project, false)
    get :list, :project_id => @project.identifier
    assert_redirected_to '/profile/login'
  end

  def test_should_allow_project_to_set_anonymous_access_when_license_allows_anonymous_users
    login_as_admin
    @controller = create_controller ProjectsController
    get :edit, :project_id => @project.identifier
    assert_response :success
    assert_select "div" do
      assert_select "input#project_anonymous_accessible"
      assert_select "label[for='project_anonymous_accessible']"
    end
  end

  def test_should_not_allow_project_to_set_anonymous_access_when_license_does_not_allows_anonymous_users
    change_license_to_not_allow_anonymous_access
    login_as_admin
    @controller = create_controller ProjectsController
    get :edit, :project_id => @project.identifier
    assert_response :success
    assert_select "input#project_anonymous_accessible", :count => 0
    assert_select "label[for='project_anonymous_accessible']", :count => 0
  end

  def test_project_list_request_should_redirect_to_login_when_license_does_not_allow_anonymous_access
    change_license_to_not_allow_anonymous_access
    @controller = create_controller ProjectsController
    get :list
    assert_redirected_to_login
  end

  def test_anonymous_user_cannot_see_overview_of_anonymous_project
    change_license_to_not_allow_anonymous_access
    assert User.current.anonymous?
    get :show, :project_id => @project.identifier
    assert_redirected_to_login
  end

  def test_anonymous_user_cannot_do_ajax_call
    change_license_to_not_allow_anonymous_access
    assert User.current.anonymous?
    @controller = create_controller CardsController
    xhr :get, :list, :project_id => @project.identifier
    assert_response 401
  end

  def test_should_display_nice_error_message_when_anonymous_users_try_to_access_a_wiki_page_that_does_not_exist
    @controller = create_controller(PagesController)
    logout_as_nil
    @request.env["HTTP_REFERER"] = 'overview'
    get :show, :project_id => @project.identifier, :pagename => 'doesnt_exist'
    assert_response :redirect
    assert_equal 'Anonymous users do not have access rights to create pages.', flash[:error]
  end

  def test_should_display_nice_error_message_when_user_which_is_not_member_try_to_access_a_wiki_page_that_does_not_exist
    @controller = create_controller(PagesController)
    login_as_longbob
    @request.env["HTTP_REFERER"] = 'overview'
    get :show, :project_id => @project.identifier, :pagename => 'doesnt_exist'
    assert_response :redirect
    assert_equal 'Anonymous users do not have access rights to create pages.', flash[:error]
  end

  private

  def assert_redirected_to_login
    assert_redirected_to :controller => "profile", :action => "login"
  end

  def assert_can_not_subscribe_by_email_using_url
    @controller = create_controller HistoryController
    assert_raise ApplicationController::UserAccessAuthorizationError do
      post :subscribe, :project_id => @project.identifier
    end
  end

  def assert_can_see_anonymous_project_on_projects_list
    @controller = create_controller ProjectsController
    get :index
    assert_response :success
    assert_template 'list'
    Rails.logger.info "[DEBUG]User.current => #{User.current.inspect}"
    Rails.logger.info "[DEBUG]Project.accessible_or_requestables_for(User.current) => #{Project.accessible_or_requestables_for(User.current).inspect}"
    assert_select 'a', {:text => @project.name}, "cannot see project on list page. response:\n#{@response.body}"
  end

  def assert_subscribe_via_email_link_count(count)
    @controller = create_controller HistoryController
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_select 'a', {:count => count, :text => 'via email'}
  end

  def assert_already_subscribed_link_count(count)
    assert_select '#subscribed-message', {:count => count}
  end

  def each_element(selector, &block)
    assert_select(selector) do |elements|
      elements.each(&block)
    end
  end
end
