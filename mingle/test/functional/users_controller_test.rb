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

# Tags:
class UsersControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller UsersController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @request.env["HTTP_REFERER"] = "http://test.host/back_url"
    @response   = ActionController::TestResponse.new
    @first_user = User.find_by_login('first')
    @member_user = User.find_by_login('member')
    @admin = User.find_by_login('admin')
    @bob = User.find_by_login('bob')
    login_as_admin
  end

  def teardown
    Authenticator.authentication = MingleDBAuthentication.new
    reset_license
    SaasTos.clear_cache!
  end

  def test_show
    get :show, :id => @first_user.id
    assert_response :success
    assert_template 'show'
    assert_select '.tabs_pane li.current', :text => 'Projects'
  end

  def test_should_display_hmac_key_tab_when_show_another_user_profile
    get :show, :id => @member_user.id
    assert_select 'div.tabs_pane' do
      assert_select "span", :html => "HMAC Auth Key", :count => 1
    end
  end

  def test_update_api_key_returns_csv_with_key_pair_for_the_user_specified
    post :update_api_key, :id => @member_user.id
    assert_response :ok
    assert_match @member_user.reload.api_key, @response.body
    assert_match "access_key_id,secret_access_key", @response.body
    assert_false @member_user.reload.api_key.include?("\n")
  end

  def test_show_with_subscription_tab_open
    get :show, :id => @first_user.id, :tab => 'subscriptions'
    assert_select '.tabs_pane li.current', :text => 'Subscriptions'
  end

  def test_show_with_favorites_tab_open
    get :show, :id => @first_user.id, :tab => 'my favorites'
    assert_select '.tabs_pane li.current', :text => 'My Favorites'
  end

  def test_show_with_projects_tab_open
    get :show, :id => @first_user.id, :tab => 'projects'
    assert_select '.tabs_pane li.current', :text => 'Projects'
  end

  def test_show_with_projects_tab_open
    get :show, :id => @first_user.id, :tab => 'OAuth Access Tokens'
    assert_select '.tabs_pane li.current', :text => 'OAuth Access Tokens'
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_change_password_and_last_login_columns_only_show_for_mingle_admin
    project_admin = first_project.admins.first
    assert !project_admin.admin?
    set_current_user(project_admin) do
      get :index
      assert_response :success
      assert_select "#last_login_at", 0
      assert_select "#change-password-column", 0
    end
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:user)
  end

  def test_create
    num_users = User.count

    post :create, :user => {:login => "newuser", :name => 'newuser@email.com', :email => "newuser@email.com", :password => "test123-", :password_confirmation => "test123-"}

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal num_users + 1, User.count
  end

  def test_creation_of_full_user_should_fail_if_max_full_user_seats_reached
    register_license(:max_active_users => User.activated_full_users)

    post :create, :user => {:login => "newuser", :name => 'newuser@email.com', :email => "newuser@email.com", :password => "test123-", :password_confirmation => "test123-"}

    assert_nil User.find_by_login('newuser')

    assert_not_nil flash[:info]
  end

  def test_should_display_light_user_and_mingle_admin_radio_buttons_on_user_new_page
    get :new

    assert_select 'input#user_user_type_light'
    assert_select 'input#user_user_type_admin'
    assert_select 'input#user_user_type_full'
  end

  def test_should_remember_user_type_selection_when_user_post_invalid_data
    post :create, :user => {:user_type => 'light'}
    assert_checked 'input#user_user_type_light'
  end

  def test_should_create_light_user
    post :create, :user => {
      :login => "newuser",
      :name => 'newuser@email.com',
      :email => "newuser@email.com",
      :password => "test123-",
      :password_confirmation => "test123-",
      :light => 'true'
    }
    assert User.find_by_login('newuser').light?
  end

  def test_should_create_admin_user
    post :create, :user => {
      :login => "newuser",
      :name => 'newuser@email.com',
      :email => "newuser@email.com",
      :password => "test123-",
      :password_confirmation => "test123-",
      :admin => '1'
    }
    assert User.find_by_login('newuser').admin?
  end

  def test_edit_profile
     get :edit_profile, :id => @first_user.id

     assert_response :success
     assert_template 'edit_profile'
     assert_equal @first_user.id, assigns(:user).id
   end

   def test_should_display_user_readonly_membership_on_show_page_when_login_as_admin
     bill = create_user!(:login => 'bill')
     first_project.add_member(bill, :readonly_member)

     get :show, :id => bill

     assert_select 'th', :text => 'Project'
     assert_select 'th', :text => 'Permissions'

     assert_select 'td', :text => 'Project One'
     assert_select 'td', :text => 'Read only team member'
   end

   def test_should_display_full_membership_on_show_page_when_login_as_admin
     bill = create_user!(:login => 'bill')
     first_project.add_member(bill)

     get :show, :id => bill

     assert_select 'td', :text => 'Team member'
   end

   def test_should_display_admin_membership_on_show_page_when_login_as_admin
     bill = create_user!(:login => 'bill')
     first_project.add_member(bill, :project_admin)

     get :show, :id => bill

     assert_select 'td', :text => 'Project administrator'
   end

   def test_select_project_assignments_should_pop_light_box
     bill = create_user!(:login => 'bill')
     xhr :get, :select_project_assignments, :id => bill
     assert @response.body.include?('InputingContexts')
   end

   # bug 10894
   def test_should_escape_user_name_on_project_assignment_popup
     bill = create_user!(:login => 'bill', :name => '<b>bill</b>')
     xhr :get, :select_project_assignments, :id => bill

     assert_equal false, @response.body.include?('<b>bill</b>')
     assert @response.body.include?('\\u0026lt;b\\u0026gt;bill\\u0026lt;/b\\u0026gt;')
   end

   def test_assign_to_projects_ignore_empty_selections
     bill = create_user!(:login => 'bill', :name => 'bill')

     post :assign_to_projects, :id => bill, :project_assignments =>{ "0" => { :project => first_project.identifier, :permission => "readonly_member" },
      "1" => { :project => "", :permission => "member" } }
     assert_response :redirect
   end

   def test_assign_to_projects_should_assign_permission_as_full_user
      bill = create_user!(:login => 'bill', :name => 'bill')

      post :assign_to_projects, :id => bill, :project_assignments => { "0" => { :project => first_project.identifier, :permission => "full_member" } }
      assert_response :redirect, :action => "edit_profile", :id => bill

      assert flash[:notice]
      assert first_project.member?(bill)
      assert !first_project.readonly_member?(bill)
   end

   def test_assign_to_projects_should_work_for_multiple_projects
     bill = create_user!(:login => 'bill', :name => 'bill')

     post :assign_to_projects, :id => bill, :project_assignments => { "0" => { :project => first_project.identifier, :permission => 'full_member' },
      "1" => { :project => filtering_tree_project.identifier, :permission => 'project_admin' } }

     assert first_project.member?(bill)
     assert filtering_tree_project.admin?(bill)
   end

   def test_project_admin_should_be_able_to_assign_to_projects
     proj_admin = login_as_proj_admin
     bill = create_user!(:login => 'bill', :name => 'bill')
     post :assign_to_projects, :id => bill, :project_assignments => { "0" => { :project => first_project.identifier, :permission => 'full_member' } }
     assert first_project.member?(bill)
   end

   def test_project_admin_should_only_be_able_to_assign_to_their_administered_projects
      proj_admin = login_as_proj_admin
      project = create_project
      bill = create_user!(:login => 'bill', :name => 'bill')
      assert !project.admin?(proj_admin)

      Project.current.deactivate
      post :assign_to_projects, :id => bill, :project_assignments => { "0" => { :project => project.identifier, :permission => 'full_member' } }
      assert_false project.member?(bill)
   end

   def test_assign_to_projects_should_assign_permission_as_readonly_user
     bill = create_user!(:login => 'bill', :name => 'bill')
     post :assign_to_projects, :id => bill, :project_assignments => { "0" => { :project => first_project.identifier, :permission => "readonly_member" } }
     assert first_project.readonly_member?(bill)
   end

   def test_assign_to_projects_should_assign_permission_as_admin_user
     bill = create_user!(:login => 'bill', :name => 'bill')
     post :assign_to_projects, :id => bill, :project_assignments => { "0" => { :project => first_project.identifier, :permission => "project_admin" } }
     assert first_project.admin?(bill)
   end

   def test_assign_to_projects_should_clear_involved_project_cache
     bill = create_user!(:login => 'bill', :name => 'bill')
     target_project = ProjectCacheFacade.instance.load_project(create_project.identifier)
     ProjectCacheFacade.instance.cache_project(target_project)

     post :assign_to_projects, :id => bill, :project_assignments => { "0" => { :project => target_project.identifier, :permission => "project_admin" } }

     target_through_cache = ProjectCacheFacade.instance.load_project(target_project.identifier)
     assert_object_id_not_equal target_project, target_through_cache
   end

   def test_should_redirect_to_user_show_on_successful_update_profile
     assert_equal @admin.login, @request.session[:login]
     put :update_profile, :id => @first_user.id, :user => {:email => "newuser@email.com", :name => "My New Name"}
     assert_redirected_to :action => 'show'
     assert_equal @admin.login, session[:login]
     assert_equal 'My New Name', User.find(@first_user.id).name
   end

   def test_add_to_projects_button_should_be_disabled_when_user_is_a_team_member_of_non_template_projects
     new_project = create_project(:template => true)
     Project.not_template.each { |project| project.add_member(@member_user) }

     get :show, :id => @member_user.id
     assert_select '#add_projects.disabled'
   end

   #bug 1470
   def test_should_render_edit_profile_when_update_profile_failed
     put :update_profile, :id => @first_user.id, :user => {:email => "newuser@email.com", :name => ""}
     assert_template 'edit_profile'
   end

   def test_should_allow_admin_to_change_any_other_users_password
     get :change_password, :id => @first_user.id
     assert_template 'change_password'
     assert_select 'input#current_password', 0

     post :update_password, :user => {:password => 'abcde1.', :password_confirmation => 'abcde1.'}, :id => @first_user.id
     assert_equal "Password was successfully changed for #{@first_user.name}.", flash[:notice]
   end

   def test_should_ask_for_current_password_when_admin_changes_their_own_password_through_users_controller
     get :change_password, :id => User.current.id
     assert_template 'change_password'
     assert_select 'input#current_password', 1

     post :update_password, :user => {:password => 'abcde1.', :password_confirmation => 'abcde1.'}, :id => User.current.id
     assert_template 'users/change_password'
     assert_equal "The current password you've entered is incorrect. Please enter a different password.", flash[:error]
   end

   def test_should_redirect_to_show_page_if_admin_change_users_password_from_profile_page
     post :update_password, :user => {:password => 'abcde1.', :password_confirmation => 'abcde1.'}, :id => @first_user.id
     assert_redirected_to :action => 'show'
   end

   def test_should_redirect_to_list_page_if_admin_change_users_password_from_list_page
     post :update_password, :user => {:password => 'abcde1.', :password_confirmation => 'abcde1.'}, :id => @first_user.id, :search => {:query => 'a'}
     assert_redirected_to :action => 'list'
   end

   def test_should_redirect_to_change_password_on_error
     get :change_password, :id => @first_user.id
     assert_template 'change_password'
     post :update_password, :user => {:password => 'abcde1.', :password_confirmation => 'efghi1.'}, :id => @first_user.id
     assert_equal "Password doesn't match confirmation", flash[:error].join
     assert_redirected_to :action => 'change_password', :id => @first_user.id
   end


  def test_editing_profile_does_not_change_password
    password_before = @member_user.password
    put :update_profile, :user => {:email => 'member@project.com', :name => 'Named Lass'}, :id => @member_user.id
    assert_equal 'Named Lass', @member_user.reload.name
    assert_equal password_before, @member_user.password
  end

  def test_update_profile_should_ignore_last_login_param
    last_login_at = Time.parse('Mon Oct 18 10:20:30 UTC 2010')
    @member_user.login_access.update_attribute(:last_login_at, last_login_at)
    put :update_profile, :user => { :name => 'linc', :last_login_at => Time.now }, :id => @member_user.id
    assert_equal last_login_at, @member_user.reload.login_access.last_login_at
  end

  def test_should_enable_checkbox_to_promote_a_user_to_admin_only_for_another_admin
    get :list
    assert_disabled "input#admin-user-#{@admin.id}"
    assert_select "input#admin-user-#{@member_user.id}"
    assert_disabled "input#admin-user-#{@member_user.id}", false
  end

  def test_should_toggle_user_admin_status
    project_member = @member_user
    assert !project_member.admin?
    post :toggle_admin, :id => project_member.id
    assert project_member.reload.admin?
    assert_equal "#{project_member.name.bold} is now an administrator.", flash[:notice]
  end

  def test_should_not_allow_deactive_user_be_an_admin
    project_member = @member_user
    project_member.update_attribute(:activated, false)
    post :toggle_admin, :id => project_member.id
    assert !project_member.reload.admin?
    assert_equal "#{project_member.name.bold} is deactivated!", flash[:error]
  end

  def test_should_not_allow_last_system_level_admin_to_be_removed
    assert_equal 1, User.find_all_by_admin(true).size
    post :toggle_admin, :id => @admin.id
    assert @admin.reload.admin? #should still be admin
    assert_equal "Administrator #{@admin.name} cannot be removed as they are the last admin", flash[:error].join
  end

  def test_should_display_editable_profile_link_to_project_admin_for_their_own_profile
    project_admin = User.find_by_login('proj_admin')
    non_admin = User.find_by_login('bob')

    set_current_user(project_admin) do
      get :index
      assert_select "#show-profile-#{project_admin.id}[href=?]", "/profile/show/#{project_admin.id}"
      assert_select "#show-profile-#{non_admin.id}[href=?]", "/users/#{non_admin.id}"
    end
  end

  def test_users_list_should_have_profile_edit_link_for_admins
    get :list
    assert_tag :a , :content => @admin.name, :attributes => { :href => url_for(:controller => "profile", :action => 'show', :id => @admin.id)}
  end

  def test_should_redirect_to_login_page_if_use_try_to_access_user_list_and_not_login_or_not_adminsitrator
    rescue_action_in_public!
    logout
    get :list
    assert_redirected_to :controller => 'profile', :action => 'login'
    login_as_member
    get :list
  end

  def test_change_password_link_should_not_be_shown_when_auth_not_support
    get :list
    assert_tag :a, :content => 'Change password'

    Authenticator.authentication = TestAuthenticationWithNoPasswordChange.new
    get :list
    assert_no_tag :a, :content => 'Change password'
  end

  def test_change_password_and_update_password_should_not_be_accessed_when_auth_not_support
    Authenticator.authentication = TestAuthenticationWithNoPasswordChange.new
    get :change_password, :id => @member_user.id
    assert_redirected_to root_url
    post :update_password, :id => @member_user.id, :user => {:password => 'pass123.', :password_confirmation => 'pass123.'}
    assert_redirected_to root_url
  end

  def test_can_create_user_when_the_version_control_user_is_empty
    post :create, :user => {:version_control_user_name => '', :login => "newuser", :name => 'newuser@email.com', :email => "newuser@email.com", :password => "test123-", :password_confirmation => "test123-"}
    assert_not_nil User.find_by_login('newuser')
  end

  def test_can_toggle_user_to_activated
    user = create_user!(:login => 'u_f_activ')
    assert user.activated?
    post :toggle_activate, :id => user.id
    assert_response :success
    assert !user.reload.activated?
    assert_equal "#{user.name.bold} is now deactivated.", flash[:notice]

    post :toggle_activate, :id => user.id
    assert user.reload.activated?
    assert_equal "#{user.name.bold} is now activated.", flash[:notice]
  end

  #TODO this test does not belong to this testcase, but haven't find a good place to put it
  def test_ajax_call_get_warm_notice_when_session_timout
    logout
    xhr :get, :index
    assert_response 401
    assert_equal "SESSION_TIMEOUT", @response.body
  end

  def test_should_not_allow_deactive_admin_self
    assert @admin.activated?
    post :toggle_activate, :id => @admin
    assert_equal "#{@admin.name.bold} has logined!", flash[:error]
    assert @admin.reload.activated?
  end

  def test_create_user_or_toggle_activaion_will_request_recheck_license
    CurrentLicense.status
    assert ThreadLocalCache.get(CurrentLicense::LICENSE_STATUS_THREADLOCAL_KEY)
    post :create, :user => {:login => "newuser", :name => 'newuser@email.com', :email => "newuser@email.com", :password => "test123-", :password_confirmation => "test123-"}
    assert_nil ThreadLocalCache.get(CurrentLicense::LICENSE_STATUS_THREADLOCAL_KEY)
  end

  def test_toggle_activate_will_request_recheck_license
    CurrentLicense.status
    assert ThreadLocalCache.get(CurrentLicense::LICENSE_STATUS_THREADLOCAL_KEY)

    user = User.find_by_login('member')
    post :toggle_activate, :id => user.id

    assert_nil ThreadLocalCache.get(CurrentLicense::LICENSE_STATUS_THREADLOCAL_KEY)
  end

  # bug2606
  def test_can_deactive_user_when_the_user_is_the_memeber_of_project_and_that_project_has_the_card_list_view
    user = create_user!
    project = create_project
    project.add_member(user)
    project.activate
    view = CardListView.find_or_construct(project, {:style => 'list', :filters => ["[dev][is][#{@first_user.login}]"]})
    view.name ='view_name'
    view.save
    post :toggle_activate, :id => user.id
    assert flash[:notice]
    assert user.activated
  end

  def test_toggle_user_to_light
    post :toggle_light, :id => @first_user.id
    assert flash[:notice]
    @first_user.reload
    assert @first_user.light?

    post :toggle_light, :id => @first_user.id
    @first_user.reload
    assert !@first_user.light?
  end

  def test_should_not_show_delete_user_link_for_any_user_in_project
    get :list
    assert_response :success
    assert_select "a#user_#{@member_user.id}_delete_user", false
  end

  def test_delete_a_deletable_user
    deletable_user = create_user!
    post :delete, :user_ids => [deletable_user]
    assert_response :redirect
    assert_equal "#{deletable_user.login.bold} deleted successfully.", flash[:notice]
    follow_redirect
    assert_template 'deletable'
    assert_nil User.find_by_login(deletable_user.login)
  end

  def test_should_show_error_when_delete_current_user
    current_user = User.current
    post :delete, :user_ids => [current_user.id]
    assert_equal "Cannot delete yourself, #{current_user.name.bold}.", flash[:error]
    assert User.find_by_login(current_user.login)
  end

  def test_should_raise_error_when_delete_a_undeletable_user
    undeletable_user = create_user!(:login => 'has_project_data')
    first_project.add_member(undeletable_user)
    create_plv!(first_project, :name => 'Newest Team Member', :data_type => ProjectVariable::USER_DATA_TYPE, :value => undeletable_user.id)
    assert_false undeletable_user.deletable?

    post :delete, :user_ids => [undeletable_user.id]

    assert_redirected_to :action => :deletable
    assert_equal "Cannot delete undeletable user #{undeletable_user.login}.", flash[:error]
    assert User.find_by_login(undeletable_user.login)
  end

  def test_should_not_show_delete_user_link_for_myself
    admin_user = create_user!(:admin => true)
    login admin_user.email
    get :list
    assert_response :success
    assert_select "a#user_#{admin_user.id}_delete_user", false
  end

  def test_last_login_should_display_blank_when_user_does_not_have_last_login_at
    user = create_user!
    login_as_admin

    get :list
    assert_select "##{user.html_id} td" do |elements|
      children = elements.collect { |element| element.children.first }
      assert_equal_ignoring_spaces '', children[6].content
    end
  end

  def test_list_should_display_last_login
    admin = login_as_admin
    admin.login_access.update_attribute(:last_login_at, Time.parse('Mon Oct 18 10:20:30 UTC 2010'))

    Clock.now_is(:year => 2010, :month => 10, :day => 18, :hour => 10, :min => 22, :sec => 10 ) do
      get :list
      assert_select 'span', :text => 'Last login'
      assert_select '.highlight td .timeago', :text => 'Mon Oct 18 10:20:30 UTC 2010'
    end
  end

  def test_should_not_show_search_info_when_query_is_empty
    get :list, :search => { :query => '' }
    assert_response :success
    assert_nil flash[:info]
  end

  def test_new_user_should_forcably_be_light_user_when_the_max_active_full_users_reached
    get :new
    assert_checked "input#user_user_type_full"
    assert_checked "input#user_user_type_light", :count => 0
    assert_checked "input#user_user_type_admin", :count => 0

    register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users + 1)

    get :new

    assert_checked "input#user_user_type_light"
    assert_disabled "input#user_user_type_admin"
    assert_disabled "input#user_user_type_full"
    assert_checked "input#user_user_type_full", :count => 0

    assert flash[:info]
  end

  def test_new_user_can_be_light_user_when_the_max_active_light_users_reached_and_still_have_full_users
    register_license(:max_light_users => User.activated_light_users)
    get :new
    assert_checked "input#user_user_type_full"
    assert_disabled "input#user_user_type_full", :count => 0
    assert_select "input#user_user_type_admin"
    assert_disabled "input#user_user_type_admin", :count => 0
    assert_disabled "input#user_user_type_light", :count => 0
  end

  def test_index_with_xhr_should_replace_users_table
    xhr :get, :index
    assert_rjs_replace_html 'content'
  end

  def test_should_prevent_change_from_light_user_to_full_user_when_the_max_active_full_users_reached
    light_user = create_user!(:name => 'new light user', :light => true)
    full_user = create_user!(:name => 'new full user')
    get :list
    assert_disabled "input#light-user-#{light_user.id}", :count => 0

    register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users + 1)
    get :list
    assert_disabled "input#light-user-#{light_user.id}"

    assert flash[:info]
  end

  def test_should_not_display_max_users_warning_to_project_admins
    register_license(:max_active_users => User.activated_full_users)
    project_admin = first_project.admins.first
    assert !project_admin.admin?
    set_current_user(project_admin) do
      get :index
      assert flash[:info].blank?
    end
  end

  def test_should_prevent_change_from_light_user_to_admin_user_when_the_max_active_full_users_reached
    register_license(:max_active_users => User.activated_full_users)
    light_user = create_user!(:name => 'new light user', :light => true)

    get :list

    assert_disabled "input#admin-user-#{light_user.id}"
    assert flash[:info]
  end

  def test_should_allow_change_full_user_to_admin_when_the_all_users_max_reached
    register_license(:max_active_users => User.activated_full_users + 1)
    full_user = create_user!(:name => 'new full user')

    get :list

    assert_disabled "input#admin-user-#{full_user.id}", :count => 0
  end

  def test_should_allow_change_light_user_to_full_user_when_the_all_users_max_reached_but_some_full_used_as_light
    register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
    light_user = create_user!(:name => 'new light user', :light => true)

    get :list

    assert_disabled "input#light-user-#{light_user.id}", :count => 0
  end

  def test_should_allow_change_light_user_to_admin_user_when_the_all_users_max_reached_but_some_full_used_as_light
    register_license(:max_active_users => User.activated_full_users + 1, :max_light_users => User.activated_light_users)
    light_user = create_user!(:name => 'new light user', :light => true)

    get :list

    assert_disabled "input#admin-user-#{light_user.id}", :count => 0
  end

  def test_user_should_be_able_to_set_light_user_when_the_max_active_light_users_reached_and_still_have_full_users
    light_user = create_user!(:name => 'new light user', :light => true)
    full_user = create_user!(:name => 'new full user')

    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)
    get :list
    assert_disabled "input#light-user-#{full_user.id}", :count => 0
    assert_disabled "input#light-user-#{light_user.id}", :count => 0
    assert !flash[:info]
  end

  def test_should_not_be_able_to_activate_full_user_when_the_max_active_full_users_reached
    inactive_full_user = create_user!(:name => 'new full user', :activated => false)
    register_license(:max_active_users => User.activated_full_users, :max_light_users => User.activated_light_users + 1)

    get :list

    assert_select "a#user_#{inactive_full_user.id}_toggle_activation", :count => 0
    assert flash[:info]
  end

  def test_should_be_able_to_activate_light_user_when_max_light_full_users_reached_but_still_have_full_users
    light_user = create_user!(:name => 'new light user', :light => true, :activated => false)
    register_license(:max_light_users => User.activated_light_users)
    get :list, :search => { :show_deactivated => '1' }
    assert_select "a#user_#{light_user.id}_toggle_activation"
    assert !flash[:info]
  end

  def test_should_not_be_able_to_activate_users_when_max_all_light_and_full_users_reached_with_no_borrowed_light_users
      register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users)
      deactivated_light_user = create_user_without_validation(:name => 'deactive light user', :light => true, :activated => false)
      deactivated_full_user = create_user_without_validation(:name => 'deactive full user', :activated => false)

      get :list
      assert_select "a#user_#{deactivated_light_user.id}_toggle_activation", :count => 0
      assert_select "a#user_#{deactivated_full_user.id}_toggle_activation", :count => 0
  end

  def test_should_not_be_able_to_activate_users_when_max_light_and_full_users_reached_including_borrowed_light_users
      register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users + 1)
      create_user!(:light => true)
      deactivated_light_user = create_user_without_validation(:name => 'deactive light user', :light => true, :activated => false)
      deactivated_full_user = create_user_without_validation(:name => 'deactive full user', :activated => false)

      get :list
      assert_select "a#user_#{deactivated_light_user.id}_toggle_activation", :count => 0
      assert_select "a#user_#{deactivated_full_user.id}_toggle_activation", :count => 0
  end

  def test_project_admin_cannot_see_favorites_or_subscriptions_of_other_users
    with_first_project do
      login_as_proj_admin
      get :show, :id => @member_user.id
      assert_select "#global_personal_views", :count => 0
      assert_select '#global_subscriptions', :count => 0
    end
  end

  def test_mingle_admin_can_see_favorites_or_subscriptions_of_other_users
    with_first_project do
      login_as_admin
      get :show, :id => @member_user.id
      assert_select "#global_personal_views"
      assert_select '#global_subscriptions'
    end
  end

  def test_project_admin_only_sees_projects_she_is_admin_of
    with_pie_chart_test_project do
      login_as_proj_admin
    end

    get :show, :id => @member_user.id

    assert_select "table#project-permissions-table>tbody>tr" do
      assert_select "td", {:text => "pie_chart_test_project", :count => 0}, "proj_admin should not see pie_chart_test_project since they aren't admin for that project"
      assert_select "td", {:text => "Project One"}, "proj_admin should see Project One since proj_admin is an admin for that project"
    end
  end

  def test_project_admin_sees_empty_membership_table_if_no_memberships_are_for_their_administered_projects
    login_as_proj_admin
    bill = create_user!(:login => 'bill')
    with_new_project do |project|
      project.add_member(bill, :readonly_member)
    end

    Project.current.deactivate
    get :show, :id => bill
    assert_select "table#project-permissions-table > tbody > tr:not([style='display:none'])", :text => 'There are currently no project assignments to list.', :count => 1
  end

  def test_mingle_admin_sees_all_projects
    rows_of_table_with_project_names_selector = "table#project-permissions-table > tbody > tr:not([style='display:none'])"
    with_pie_chart_test_project do
      login_as_admin
      get :show, :id => @member_user.id
      assert_select rows_of_table_with_project_names_selector, :count => @member_user.projects.count
    end
  end


  def test_project_admin_should_see_users_permissons_contain_links_to_each_projects_team_page
    proj_admin = login_as_proj_admin
    visible_projs = @bob.projects_visible_to(proj_admin)

    get :show, :id => @bob.id
    assert_select "table#project-permissions-table tbody tr:not([style='display:none'])", :count => visible_projs.size do
      visible_projs.each do |project|
        assert_select "td a[href=/projects/#{project.identifier}/team/list]", { :text => project.name }
      end
    end
  end

  def test_add_to_projects_button_disabled_if_user_already_belongs_to_all_projects_this_project_admin_is_admin_of
    proj_admin = login_as_proj_admin
    new_project = create_project
    new_project.add_member(proj_admin, :project_admin)

    user_on_same_projects_as_admin = create_user!
    proj_admin.projects.each{|project| project.add_member(user_on_same_projects_as_admin)}

    get :show, :id => user_on_same_projects_as_admin.id
    assert_select '#add_projects.disabled'
  end

  def test_add_to_projects_button_disabled_if_user_already_belongs_to_all_projects_this_project_admin_is_admin_of_but_they_each_belong_to_mutually_exclusive_projects
    proj_admin = login_as_proj_admin
    new_project = create_project
    new_project.add_member(proj_admin, :project_admin)

    user = create_user!
    proj_admin.projects.each{|project| project.add_member(user)}

    project_user_isnt_part_of = create_project
    project_user_isnt_part_of.add_member(proj_admin)

    project_admin_isnt_part_of = create_project
    project_admin_isnt_part_of.add_member(user)

    Project.current.deactivate
    get :show, :id => user.id
    assert_select '#add_projects.disabled'
  end

  def test_add_to_projects_button_disabled_when_user_is_already_a_project_admin_of_the_same_projects_as_a_project_admin
    proj_admin = create_user!
    login(proj_admin.email)
    new_project = create_project
    new_project.add_member(proj_admin, :project_admin)

    user_on_same_projects_as_admin = create_user!
    proj_admin.projects.each {|project| project.add_member(user_on_same_projects_as_admin, :project_admin)}

    get :show, :id => user_on_same_projects_as_admin.id
    assert_select '#add_projects.disabled'
  end

  def test_project_admin_can_see_add_to_projects_button
    login_as_proj_admin
    get :show, :id => @member_user.id
    assert_select "#add_projects"
  end

  def test_show_page_list_unexpired_users_oauth_access_tokens_in_client_name_order
    Oauth2::Provider::OauthToken.find_all_with(:user_id, @first_user.id).map(&:destroy)

    client1 = Oauth2::Provider::OauthClient.create!(:name => 'some application', :redirect_uri => 'http://app1.com/bar')
    client2 = Oauth2::Provider::OauthClient.create!(:name => 'another application', :redirect_uri => 'http://app2.com/bar')
    client3 = Oauth2::Provider::OauthClient.create!(:name => 'old applicaton', :redirect_uri => 'http://app2.com/bar')

    token1 = client1.create_token_for_user_id(@first_user.id)
    token2 = client2.create_token_for_user_id(@first_user.id)
    token3 = client3.create_token_for_user_id(@first_user.id)

    token3.expires_at = 2.days.ago
    token3.save

    @request.env["HTTPS"] = 'on'
    get :show, :id => @first_user.id
    assert_response :success
    assert_select "tr.oauth-token", :count => 2
    assert_select "tr.oauth-token:nth-child(1) td:first-child", :text => 'another application'
    assert_select "tr.oauth-token:nth-child(2) td:first-child", :text => 'some application'
    assert_select "#destroy_oauth_token_#{token1.id}", :count => 1
    assert_select "#destroy_oauth_token_#{token2.id}", :count => 1
    assert_select "#destroy_oauth_token_#{token3.id}", :count => 0
  end

  def test_can_not_see_profile_of_a_system_user
    user = User.create_or_update_system_user(:login => 'sa', :name => 'System Administrator')
    get :show, :id => user.id
    assert_response :not_found
  end

  def test_should_show_all_deletable_users
    deletable_users = User.all.select(&:deletable?)
    get :deletable
    assert_select '#users tbody tr', :count => deletable_users.count
    deletable_users.each do |deletable_user|
      assert_select 'td', :text => deletable_user.login, :count => 1
    end
  end

  def test_should_show_message_when_no_users_deletable
    with_first_project do |project|
      User.all.each do |user|
        project.add_member(user)
        create_murmur(:author => user)
      end
    end
    assert_equal 0, User.all.select(&:deletable?).count
    get :deletable
    assert_select 'tbody tr', :count => 1, :text => 'No users can be deleted'
  end

  def test_logged_in_user_should_not_be_deletable
    deletable_admin_user = create_user!(:admin => true)
    login(deletable_admin_user)
    get :deletable
    assert_false User.current.deletable?
    assert_select 'td', :text => User.current.login, :count => 0
  end

  def test_login_is_not_editable_if_profile_server_configured
    get :edit_profile, :id => @first_user.id
    assert_response :success
    assert_login_field_not_disabled

    with_profile_server_configured do
      get :edit_profile, :id => @first_user.id
      assert_response :success
      assert_login_field_disabled
    end
  end

  def test_login_is_editable_when_creating_user_when_profile_server_configured
    with_profile_server_configured do
      get :new
      assert_response :success
      assert_login_field_not_disabled

      post :create, :user => {:login => "newuser", :email => 'newuser@email.com'}
      assert_response :success
      assert_login_field_not_disabled
    end
  end

  def test_should_redirect_to_saas_tos_if_tos_not_accepted
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      login_as_admin
      get :index
      assert_redirected_to({:controller => 'saas_tos', :action => 'show'})
    end
  end

  def test_should_not_redirect_to_saas_tos_if_not_configured
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(false) do
      get :index
      assert_response :success
    end
  end

  def test_should_not_redirect_to_saas_tos_if_already_accepted
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      SaasTos.accept(User.current)
      get :index
      assert_response :success
    end
  end

  def test_should_mark_as_notification_read_by_user
    put :mark_notification_read, :id => User.current.id, :message => "check out my new colors!"
    assert_response :success
    assert_not_nil User.current.reload.read_notification_digest
  end

  def test_should_mark_as_notification_read_by_system_user
    requires_jruby do
      logout
      begin
        java.lang.System.setProperty('mingle.systemUser', 'systemuser')
        User.create_or_update_system_user(:login => "systemuser", :name => 'system', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :activated => true)

        login('systemuser')

        put :mark_notification_read, :id => User.current.id, :message => "check out my new colors!"
        assert_response :success
        assert_not_nil User.current.reload.read_notification_digest
      ensure
        java.lang.System.clearProperty('mingle.systemUser')
      end
    end
  end

  private

  def logout
    logout_as_nil
  end

  def assert_login_field_disabled
    assert_select "#user_login[disabled=disabled]"
  end

  def assert_login_field_not_disabled
    assert_select "#user_login"
    assert_select "#user_login[disabled=disabled]", :count => 0
  end

  def assert_profile_page_only_tab_visible_is(tab_id)
    all_tabs = %w{ #projects-active-tab #subscriptions-active-tab #my-favorites-active-tab #oauth-access-tokens-active-tab }
    visible_tab = all_tabs.delete tab_id
    assert visible_tab, "Only #{all_tabs.inspect} are possible"
    all_tabs.each { |invisible_tab| assert_tab_invisible invisible_tab }
    assert_tab_visible visible_tab
  end
end

class TestAuthenticationWithNoPasswordChange
  def authenticate?(contrller)
    return true
  end

  def supports_password_change?
    return false
  end
end
