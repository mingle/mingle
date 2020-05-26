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

class ProfileControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller ProfileController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    rescue_action_in_public!
    ActionMailer::Base.deliveries = []
    @member_user = create_user!
    @member_name = @member_user.name
    @admin = User.find_by_login('admin')
    @bob = User.find_by_login('bob')
    Project.find(:all).each{ |p| set_anonymous_access_for(p, false) }
    login(@member_user)
    @original_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_url = 'http://test.host'
    WebMock.reset!
    WebMock.disable_net_connect!
  end

  def teardown
    MingleConfiguration.site_url = @original_site_url
    Authenticator.authentication = MingleDBAuthentication.new
    WebMock.allow_net_connect!
  end

  def test_update_password_should_redirect_to_first_project_if_only_project_is_accessible
    logout_as_nil
    u = create_user!
    lpt = u.login_access.generate_lost_password_ticket!
    project = create_project(:users => [u])

    post :update_password, :user => {:password => 'pass1!', :password_confirmation => 'pass1!' }, :lpt => lpt, :id => u.id
    assert_redirected_to :controller => "projects", :action => "show", :project_id => project.identifier

    create_project(:users => [u])
    lpt = u.login_access.generate_lost_password_ticket!

    post :update_password, :user => {:password => 'pass1!', :password_confirmation => 'pass1!' }, :lpt => lpt, :id => u.id
    assert_redirected_to :controller => "projects", :action => "index"
  end

  def test_login_page_sets_correct_label
    get :login
    assert_select "label[for='user_login']", :text => "Sign-in name or email:"
  end

  def test_ignore_login_request_after_login_same_user_failed_10_times
    logout
    10.times do
      post :login, :user => {:login => "bob", :password => "wrong"}
    end
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}
    assert_equal nil, @request.session[:login]
    assert_select '.warning-box', :text => "You have attempted to log in 10 times. Please try again in one minute."
  end

  def test_auth_bob
    logout
    @request.session['return-to'] = "/bogus/location"
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}
    assert_equal 'bob', @request.session[:login]
    assert_no_cookie('login')
    assert_redirected_to "/bogus/location"
  end

  def test_invalid_login
    logout
    post :login, :user => {:login => "bob", :password => "not_correct"}
    assert(!@response.has_session_object?(:login))
    assert(@response.has_template_object?('login'))
  end

  def test_login_logoff
    session_id = fake_session.session_id

    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}

    @request.session[:cards_view] = {:columns=>"browser", :tagged_with=>"hello"}
    assert(@response.has_session_object?(:login))
    assert(@response.has_session_object?(:cards_view))

    get :logout

    assert_redirected_to login_url
    assert(!@response.has_session_object?(:login))
    assert(!@response.has_session_object?(:cards_view))
    assert User.current.anonymous?
  end

  def test_logoff_redirects_to_overview_when_anonymous_projects_are_present
    session_id = fake_session.session_id

    set_anonymous_access_for(Project.first, true)

    get :logout
    assert_redirected_to projects_url
  end

  def test_logoff_redirects_to_login_when_no_anonymous_projects_are_present
    session_id = fake_session.session_id

    get :logout
    assert_redirected_to login_url
  end

  def test_login_should_set_user_last_login_at
    logout
    bob = User.find_by_login('bob')
    bob.login_access.update_attribute(:last_login_at,  nil)

    Clock.now_is(:year => 2010, :month => 10, :day => 18, :hour => 10, :min => 20, :sec => 30 ) do
      post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}
      assert_response :redirect
    end

    assert_equal DateTime.civil(2010,10,18,10,20,30), bob.login_access.reload.last_login_at
  end

  def test_login_should_trim_username_and_password
    logout
    post :login, :user => {:login => " bob ", :password => "  #{MINGLE_TEST_DEFAULT_PASSWORD} "}
    assert @response.has_session_object?(:login)
  end

  def test_show
    get :show, :id => @member_user.id

    assert_response :success
    assert_template 'users/show'
    assert_not_nil assigns(:user)
    assert_tag :a, :content => 'Edit', :attributes => {:href => url_for(:action => 'edit_profile', :id => @member_user.id)}
  end

  def test_edit_profile
    get :edit_profile, :id => @member_user.id
    assert_response :success
    assert_template 'users/edit_profile'
    assert_not_nil assigns(:user)
    assert_select "input[name='user[login]'][value='#{@member_user.login}']"
  end

  class ExternalAuth < MingleDBAuthentication
    def initialize(can_connect=true)
      @can_connect = can_connect
    end
    def is_external_authenticator?; true end
    def managing_user_profile?; true end
    def sign_out_url(callback_url)
      "http://external_auth.com/logout?callback=#{callback_url}"
    end
    def sign_in_url
      "http://external_auth.com/login"
    end
    def can_connect?
      @can_connect
    end
  end

  def test_user_can_not_edit_display_name_and_email_if_exteral_authorticator_declare_manange_profiles
    Authenticator.authentication = ExternalAuth.new
    get :edit_profile, :id => @member_user.id
    assert_response :success
    assert_template 'users/edit_profile'
    assert_select "input[name='user[login]']", :count => 0
    assert_select "input[name='user[name]']", :count => 0
    assert_select "input[name='user[email]']", :count => 0
  ensure
    Authenticator.authentication = nil
  end

  def test_edit_profile_should_not_show_add_projects_for_non_admin_users
    login_as_admin
    get :show, :id => @admin.id
    assert_select '#add_projects'

    login_as_member
    get :show, :id => @member_user.id
    assert_select '#add_projects', :count => 0
  end

  def test_update_profile
    assert_not_equal 'updated_member', @request.session[:login]
    put :update_profile, :id => @member_user.id, :user => {:login => 'updated_member', :name => 'The Non Admin Fellow',
      :email => "newuser@email.com", :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD}

    assert_redirected_to :action => 'show', :controller => 'profile'
    assert_equal 'The Non Admin Fellow', User.find_by_login(@request.session[:login]).name
    assert_equal 'updated_member', @request.session[:login]
  end

  def test_update_should_back_to_edit_if_error
    put :update_profile, :id => @member_user.id, :user => {:name => 'The Admin Guy', :email => "wrong email"}
    assert_template 'users/edit_profile'
  end

  def test_update_does_not_change_password
    password_before = @member_user.password
    put :update_profile, :user => {:email => 'member@project.com', :name => 'Named Lass'}, :id => @member_user.id
    assert_equal 'Named Lass', @member_user.reload.name
    assert_equal password_before, @member_user.password
  end

  def test_set_password
    logout_as_nil
    new_user = create_user! :login => 'new_person'
    get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
    assert_response :success
    assert_select 'h1', :text => "Please set your password"
    assert_tag 'input', :attributes => {:type => 'submit', :value => "Set password"}
  end

  def test_tos_is_presented_per_configuration
    logout_as_nil
    new_user = create_user! :login => 'new_person'
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(false) do
      get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
      assert_response :success
      assert_no_tag 'input', :attributes => {:type => 'checkbox', :id => 'saas_tos_accepted'}
    end
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
      assert_response :success
      assert_tag 'input', :attributes => {:type => 'checkbox', :id => 'saas_tos_accepted'}
    end
  end

  def test_tos_is_not_presented_if_already_accepted
    logout_as_nil
    new_user = create_user! :login => 'new_person'
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      SaasTos.accept(User.current)
      get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
      assert_response :success
      assert_no_tag 'input', :attributes => {:type => 'checkbox', :id => 'saas_tos_accepted'}
    end
  end

  class SaasSsoAuthenticationStub
    def sign_in_url(service)
      "http://sso.minglesaas.com/login?service=#{service}"
    end

    def supports_password_change?
      true
    end

    def is_external_authenticator?
      true
    end

    def can_connect?
      true
    end
  end


  def test_login_is_set_from_session
    logout_as_nil
    user = create_user! :login => 'joe', :email => 'joe+test@tw.com'
    session['user_email'] = user.email
    saas_authentication = SaasSsoAuthenticationStub.new
    Authenticator.authentication = saas_authentication

    get :login
    assert_redirected_to "http://sso.minglesaas.com/login?service=http://test.host/profile/login&login=#{CGI.escape(user.email)}"
  end

  def test_when_complex_password_required_set_password_gives_hint
    logout_as_nil
    new_user = create_user! :login => 'new_person'
    get :set_password, :ticket => new_user.login_access.generate_lost_password_ticket!
    assert_response :success
    assert_select 'div', :text => /At least/
  end

  def test_password_should_be_emptied_when_edit_password
    get :change_password, :id => @member_user.id
    assert_equal "", assigns(:user).password
    assert_template 'users/change_password'
    assert_tag 'input', :attributes => {:type => 'submit', :value => "Change password"}
  end

  def test_validation_for_password_and_confirmation_trigger_when_changing_password
    post :update_password, :user => {:password => 'pword1-', :password_confirmation => 'Pword1-'}, :current_password => MINGLE_TEST_DEFAULT_PASSWORD, :id => @member_user.id
    assert_tag 'div', :attributes => {:class => 'field_error'}, :content => "Password doesn&#39;t match confirmation"
  end

  def test_should_not_allow_password_change_when_current_password_provided_is_wrong
    post :update_password, :user => {:password => 'pass1!', :password_confirmation => 'pass1!' }, :current_password => 'wrong', :id => @member_user.id
    assert_template 'users/change_password'
    assert_equal "The current password you've entered is incorrect. Please enter a different password.", flash[:error]
  end

  def test_should_not_allow_access_to_set_password_when_valid_ticket_is_not_provided
    get :set_password, :id => @member_user.id
    assert_response :forbidden
  end

  def test_show_current_password_input_while_changing_password
    get :change_password, :id => @member_user.id
    assert_response :ok
    assert_select 'input#current_password', 1
  end

  def test_updating_password_should_match_current_password
    post :update_password, :user => {:password => 'pass1!', :password_confirmation => 'pass1!' }, :current_password => MINGLE_TEST_DEFAULT_PASSWORD, :id => @member_user.id
    assert /Password was successfully changed/ =~ flash[:notice]
    assert_response :redirect
  end

  def test_should_not_show_current_password_input_when_there_is_ticket_for_recover_password
    ticket = @member_user.login_access.generate_lost_password_ticket!
    get :change_password, :id => @member_user.id, :ticket => ticket
    assert_response :ok
    assert_select 'input#current_password', 0
  end

  def test_should_accept_tos_when_selected_on_the_change_password_form
    ticket = @member_user.login_access.generate_lost_password_ticket!
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      SaasTos.destroy_all
      post :update_password, :user => {:password => 'p@ssw0rd', :password_confirmation => 'p@ssw0rd'}, :saas_tos_accepted => "accepted", :id => @member_user.id, :ticket => ticket
      assert SaasTos.accepted?
    end
  end

  def test_should_not_update_tos_accepted_when_passwords_dont_match
    ticket = @member_user.login_access.generate_lost_password_ticket!
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      SaasTos.destroy_all
      post :update_password, :user => {:password => 'p@ssw0rd1', :password_confirmation => 'p@ssw0rd'}, :saas_tos_accepted => "accepted", :id => @member_user.id, :ticket => ticket
      assert !SaasTos.accepted?
    end
  end

  def test_authenticate_to_slack_should_redirect_to_user_profile_slack_tab_when_user_is_not_authenticated
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'

    MingleConfiguration.overridden_to(
        saas_env: 'test',
        slack_app_url: 'https://slackserver.com',
        app_namespace: 'authorized-tenant',
        slack_encryption_key: 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:user_integration_status)
          .returns({authenticated: false})

      get :authenticate_in_slack

      assert_redirected_to action: :show, id: User.current.id, tab: 'Slack'
    end
  end

  def test_authenticate_to_slack_should_redirect_to_root_slack_integration_not_created
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'

    MingleConfiguration.overridden_to(
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED'})

      get :authenticate_in_slack
      assert_response :redirect
      assert_redirected_to root_url
    end
  end

  def test_authenticate_to_slack_should_redirect_to_root_when_user_already_authenticated
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'

    MingleConfiguration.overridden_to(
        :saas_env => 'true',
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:user_integration_status)
          .returns({ authenticated: true })

      get :authenticate_in_slack

      assert_response :redirect
      assert_redirected_to root_url
    end
  end

  def test_authenticate_to_slack_should_redirect_to_login_page_if_user_not_logged_in
    logout
    get :authenticate_in_slack, :id => @member_user.id

    assert_response :redirect
    assert_redirected_to :controller => "profile", :action => "login"
  end

  def test_should_not_update_passwords_when_tos_not_accepted
    MingleConfiguration.with_need_to_accept_saas_tos_overridden_to(true) do
      SaasTos.destroy_all
      @member_user.change_password! :password => "tw@rk3r", :password_confirmation => "tw@rk3r"

      old_password = @member_user.reload.password
      assert !SaasTos.accepted?

      ticket = @member_user.login_access.generate_lost_password_ticket!
      post :update_password, :user => {:password => 'p@sser2', :password_confirmation => 'p@sser2'}, :id => @member_user.id, :ticket => ticket

      assert_equal old_password, @member_user.reload.password
    end
  end

  def test_should_not_allow_current_user_to_edit_anyones_details_apart_from_themselves
    get :edit_profile, :id => @admin.id
    assert_redirected_to root_url
    assert_equal ApplicationController::FORBIDDEN_MESSAGE, flash[:error]
  end

  def test_should_cancel_out_of_edit_profile_to_correct_return_url
    get :edit_profile, :id => @member_user.id
    assert_select "a.cancel" do
      assert_select "[onclick=?]", "window.location='/profile/show/#{@member_user.id}'; return false;"
    end
  end

  def test_should_inform_valid_user_of_email_sent_when_recovering_password
    logout
    post :recover_password, :login  => @member_user.login
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert ActionMailer::Base.deliveries.first.body.include?("reported a lost password at http://test.host")
    assert @member_user.email, ActionMailer::Base.deliveries.first.to
  end

  def test_forgot_password_should_show_email_as_an_option
    logout
    get :forgot_password
    assert_response :success
    assert_select 'label[for="login_name"]', 'Sign-in name or email:'
  end

  def test_recover_password_by_email
    logout
    post :recover_password, :login  => @member_user.email.upcase
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert ActionMailer::Base.deliveries.first.body.include?("reported a lost password at http://test.host")
    assert_equal [@member_user.email], ActionMailer::Base.deliveries.first.to
  end

  def test_should_inform_valid_user_that_password_cannot_be_recovered_when_no_email_address
    logout
    @member_user.update_attribute(:email, nil)
    post :recover_password, :login  => @member_user.login
    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_equal "Your profile does not contain an email address and therefore Mingle is unable to send you a password reset notice. Please contact your Mingle administrator and request that your password be reset.", flash[:error]
  end

  def test_should_redirect_user_to_change_password_if_user_have_correct_key
    logout
    ticket = @member_user.login_access.generate_lost_password_ticket!
    get :change_password, :ticket => ticket
    assert_template 'users/change_password'
  end

  def test_should_show_error_message_if_can_not_find_login_name_from_users
    logout
    post :recover_password, :login => 'not_exitst_login'
    assert_equal "There is no registered user with sign-in name not_exitst_login", flash[:error]
  end

  def test_should_not_be_update_password_after_logout
    logout
    post :update_password, :user => {:password => 'pwd123-', :password_confirmation => 'pwd123-'}, :id => @member_user.id
    assert_redirected_to :action => 'login'
  end

  def test_should_update_password_and_redirect_to_all_projects_page_if_user_have_correct_key
     logout
     ticket = @member_user.login_access.generate_lost_password_ticket!
     post :update_password, :user => {:password => 'pwd123-', :password_confirmation => 'pwd123-'}, :ticket => ticket
     assert_redirected_to :controller => 'projects', :action => 'index'
  end

  def test_should_redirect_user_to_forgotten_password_page_if_after_timeout_period
    logout
    old_ticket = @member_user.login_access.generate_lost_password_ticket!
    @member_user.login_access.update_attributes(:lost_password_reported_at => Clock.now - 61.minutes)

    get :change_password, :ticket => old_ticket

    assert_equal 'Your url has expired. Please provide your email again.', flash[:error]
    assert_redirected_to :action => 'forgot_password'
  end

  def test_should_allow_forgot_password_without_checking_expiration
    def @controller.check_license_expiration
      redirect_to :controller => 'license', :action => 'warn'
    end

    get :forgot_password
    assert_response :success
  end

  def test_should_allow_change_password_without_checking_expiration
    logout
    old_ticket = @member_user.login_access.generate_lost_password_ticket!
    get :change_password, :ticket => old_ticket

    assert_response :success
  end

  def test_should_store_ticket_if_attempting_to_change_password_with_ticket
    logout
    old_ticket = @member_user.login_access.generate_lost_password_ticket!
    get :change_password, :ticket => old_ticket
    assert_tag 'input', :attributes => {:type => 'hidden', :name => 'ticket', :value => old_ticket}
  end

  def test_user_should_not_change_other_user_password_from_profile
    get :change_password, :id => @admin.id
    assert_redirected_to root_url
    post :update_password, :user => {:password => 'pwd123', :password_confirmation => 'pwd123'}, :id => @admin.id
    assert_redirected_to root_url
  end

  def test_should_redirect_to_forgot_password_if_user_is_login_and_try_to_use_expire_ticket
    get :change_password, :id => @member_user.id, :ticket => "expire ticket"
    assert_redirected_to :action => 'forgot_password'
  end

  def test_login_should_redirect_to_signup_if_user_is_empty
    logout
    User.find(:all).each(&:destroy_without_callbacks)
    assert User.no_users?

    get :login
    assert_redirected_to :controller => "install"
  end

  def test_logout_should_redirect_to_external_logout_page
    Authenticator.authentication = ExternalAuth.new
    get :logout
    assert_redirected_to "http://external_auth.com/logout?callback=http://test.host/profile/login"
  end

  def test_should_show_error_when_external_logout_service_is_not_existing
    Authenticator.authentication = ExternalAuth.new(false)
    get :logout
    assert_template "errors/connection_failure_error"
  end

  def test_forgot_password_link_should_not_be_shown_when_auth_not_support
    logout
    get :login
    assert_tag :a,:content => 'Forgotten your password?'

    Authenticator.authentication = ExternalAuthenticationWithNoPasswordRecoveryAndPasswordChange.new
    get :login
    assert_no_tag :a,:content => 'Forgotten your password?'
  end

  def test_forgot_password_and_recovery_password_should_not_be_accessed_when_auth_not_support
    logout
    Authenticator.authentication = ExternalAuthenticationWithNoPasswordRecoveryAndPasswordChange.new
    get :forgot_password
    assert_response :redirect
    assert_equal 'Password recovery is not supported.', flash[:error]

    post :recovery_password, :email => @member_user.email
    assert_response :redirect
    assert_equal 'Password recovery is not supported.', flash[:error]
  end

  def test_change_password_link_should_not_be_shown_when_auth_not_support
    get :show, :id => @member_user.id
    assert_tag :a, :content => 'Change password'

    Authenticator.authentication = ExternalAuthenticationWithNoPasswordRecoveryAndPasswordChange.new
    get :show, :id => @member_user.id
    assert_no_tag :a, :content => 'Change password'
  end

  def test_change_password_and_update_password_should_not_be_accessed_when_auth_not_support
    Authenticator.authentication = ExternalAuthenticationWithNoPasswordRecoveryAndPasswordChange.new
    get :change_password, :id => @member_user.id
    assert_redirected_to root_url
    post :update_password, :id => @member_user.id, :user => {:password => 'pass123.', :confirm_password => 'pass123.'}
    assert_redirected_to root_url
  end

  def test_user_should_not_login_if_user_is_been_deactivated
    logout
    user = create_user!(:login => 'deactivate', :activated => false)
    post :login, :user => {:login => user.login, :password => MINGLE_TEST_DEFAULT_PASSWORD}
    get :controller => 'projects'
    assert_redirected_to login_url
    assert_equal "The Mingle account for #{user.login.bold} is no longer active. Please contact your Mingle administrator to resolve this issue.", flash[:error]
    assert_equal nil, session[:login]
    assert User.current.anonymous?
  end

  def test_should_not_redirect_if_user_is_been_deactivated_when_using_external_auth_system
    Authenticator.class_eval do
      class << self
        alias_method "old_using_external_authenticator?", 'using_external_authenticator?'
        def using_external_authenticator?; true end
      end
    end
    logout
    user = create_user!(:login => 'deactivate', :activated => false)
    post :login, :user => {:login => user.login, :password => MINGLE_TEST_DEFAULT_PASSWORD}
    get :controller => 'projects'
    assert_template 'errors/external_authentication_error'
    assert_equal nil, session[:login]
    assert User.current.anonymous?
  ensure
    Authenticator.class_eval do
      class << self
        alias_method 'using_external_authenticator?', "old_using_external_authenticator?"
      end
    end
  end


  pending 'will put it into acceptance test where we can actually delete the smtp_config.yml'
  def test_should_warn_user_with_useful_message_if_the_mail_server_is_not_configured
    does_not_work_with_jruby do
      logout
      FileUtils.mv(File.join(Rails.root, "config", 'smtp_config.yml'), File.join(Rails.root, "config", 'smtp_config.yml.back'))
      begin
        SmtpConfiguration.create({:smtp_settings => {:address => 'unknown'}}, SMTP_CONFIG_YML, true)
        post :recover_password, :login => @member_user.login
        follow_redirect
        assert_error 'This feature is not configured. Contact your Mingle administrator for details.'
      ensure
        FileUtils.mv(File.join(Rails.root, "config", 'smtp_config.yml.back'), File.join(Rails.root, "config", 'smtp_config.yml'))
      end
    end
  end

  def test_login_with_remember_me
    session_id = fake_session.session_id

    logout
    @request.session['return-to'] = "/bogus/location"
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => true
    assert_equal 'bob', @request.session[:login]
    assert_cookie 'login'
    login_cookie = cookies['login']
    assert_equal login_cookie, User.find_by_login("bob").login_access.login_token
    assert_redirected_to "/bogus/location"

    logout

    @request.cookies['login'] = login_cookie
    get :show, :id => @bob.id
    assert_template 'users/show'

    get :logout
    assert(!@response.has_session_object?(:login))
    assert(!@response.has_session_object?(:cards_view))
    assert User.current.anonymous?
    assert_nil @bob.reload.login_access.login_token
    assert_no_cookie('login')

    @request.cookies['login'] = login_cookie
    get :show, :id => @bob.id
    assert_redirected_to :action => :login
    logout
  end

  def test_should_redirect_to_specified_url_after_login_regardless_of_remember_me
    logout
    @request.session['return-to'] = "/bogus/location"
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => true
    assert_equal 'bob', @request.session[:login]
    assert_cookie 'login'
    assert_redirected_to "/bogus/location"
    logout

    @request.session['return-to'] = "/bogus/location"
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => false
    assert_equal 'bob', @request.session[:login]
    assert_no_cookie 'login'
    assert_redirected_to "/bogus/location"
    logout
  end

  def test_should_redirect_to_overview_page_of_last_visited_project_after_login_when_remember_me_is_off
    logout
    @request.session['return-to'] = nil
    @request.cookies['last-visited-project'] = CGI::Cookie::new("last-visited-project", first_project.identifier)

    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => false
    assert_redirected_to "/projects/#{first_project.identifier}"
    logout
  end

  def test_should_redirect_to_all_projects_after_login_when_last_visited_project_is_invalid_and_remember_me_is_off
    logout
    @request.session['return-to'] = nil
    @request.cookies['last-visited-project'] = CGI::Cookie::new("last-visited-project", 'invalid')

    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => false
    assert_redirected_to "/"
    logout
  end

  def test_should_redirect_to_all_projects_after_login_when_last_visited_project_has_been_deleted_and_remember_me_is_off
    with_new_project do |project|
      logout
      @request.session['return-to'] = nil
      @request.cookies['last-visited-project'] = CGI::Cookie::new("last-visited-project", project.identifier)

      project.destroy
    end

    Project.current.deactivate
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => false
    assert_redirected_to "/"
    logout
  end

  def test_should_delete_session_id_on_logout
    session_id = fake_session.session_id

    get :logout

    assert_nil Session.find_by_session_id(session_id)
  end

  def test_should_redirect_to_overview_page_of_last_visited_project_when_user_checked_remember_me_and_did_not_specify_url
    logout
    @request.session['return-to'] = nil
    @request.cookies['last-visited-project'] = CGI::Cookie::new("last-visited-project", first_project.identifier)
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => true
    assert_equal 'bob', @request.session[:login]
    assert_cookie 'login'
    assert_redirected_to "/projects/#{first_project.identifier}"
    logout
  end

  def test_should_redirect_to_all_projects_after_login_when_user_has_no_access_to_last_visited_project_and_remember_me_is_off
    project_bob_cannot_access = create_project

    logout
    @request.session['return-to'] = nil
    @request.cookies['last-visited-project'] = CGI::Cookie::new("last-visited-project", project_bob_cannot_access.identifier)

    Project.current.deactivate
    post :login, :user => {:login => "bob", :password => MINGLE_TEST_DEFAULT_PASSWORD}, :remember_me => false
    assert_redirected_to "/"
    logout
  end

  def test_can_see_history_subscription_for_user
    with_first_project do |project|
      first_card_number = project.cards.first.number
      project.deactivate

      HistorySubscription.with_options(:user => @member_user, :project_id => project.id, :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1) do |history|
        history.create
        history.create :filter_params => { :card_number => first_card_number }
        history.create :filter_params => { :page_identifier => "First_Page" }
      end

      get :show, :id => @member_user.id

      assert_select "table#global_subscriptions" do
        assert_select "td", :minimum => 7
        assert_select "td", :text => project.name
        assert_select "td", :text => "(anything)"
        assert_select "td", :text => "(anyone)"
      end
      assert_select "table#card_subscriptions" do
        assert_select "td", :minimum => 5
        assert_select "td", :text => "##{first_card_number}"
      end
      assert_select "table#page_subscriptions" do
        assert_select "td", :minimum => 4
        assert_select "td", :text => "First Page"
      end
    end
  end

  def test_can_see_tagged_with_on_history_subscriptions
    @project = Project.find_by_identifier('first_project')

    HistorySubscription.with_options(:user => @member_user, :project_id => @project.id, :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1) do |history|
      history.create :filter_params => { :acquired_filter_tags => "demonworm,spacebaby,chusayshello", :involved_filter_tags => "hiqianqian" }
    end

    get :show, :id => @member_user.id

    assert_select "table#global_subscriptions" do
      assert_select "td", :minimum => 7
      assert_select "td", :html => "<div>Tagged with #{"demonworm".html_bold}, #{"spacebaby".html_bold} and #{"chusayshello".html_bold}</div>"
      assert_select "td", :html => "<div>Tagged with #{'hiqianqian'.html_bold}</div>"
    end
  end

  def test_show_will_display_personal_favorites
    with_first_project do |project|
      project.card_list_views.create_or_update(:view => {:name => 'view1'}, :style => 'list', :user_id => @member_user.id)
    end
    get :show, :id => @member_user.id
    assert_response :success

    assert_select 'table#global_personal_views' do
      assert_select "td", :html => "Project One"
      assert_select "td", :text => "view1"
      assert_select "td", :html => /<a.*Delete.*\/a>/
    end
  end

  def test_project_admin_can_see_their_personal_favorites_and_subscriptions
    proj_admin = login_as_proj_admin
    get :show, :id => proj_admin.id
    assert_select 'table#global_personal_views'
    assert_select "#global_subscriptions"
    assert_select "#card_subscriptions"
    assert_select "#page_subscriptions"
  end

  def test_non_project_admin_can_see_all_their_own_projects
    bob = login_as_bob
    get :show, :id => bob.id
    assert_select "table#project-permissions-table > tbody > tr:not([style='display:none'])", :count => bob.projects.count do
      bob.projects.each do |project|
        assert_select "td", { :text => project.name }
      end
    end
  end

  def test_project_admin_can_see_all_their_own_projects
    proj_admin = login_as_proj_admin
    with_new_project do |project|
      project.add_member(proj_admin)
      get :show, :id => proj_admin.id
      assert_select "table#project-permissions-table tbody tr:not([style='display:none'])", :count => proj_admin.projects.count do
        assert_select "td", { :text => project.name }
      end
    end
  end

  def test_users_project_permissions_should_contain_links_to_each_projects_overview_page
    bob = login_as_bob
    get :show, :id => bob.id

    assert_select "table#project-permissions-table tbody tr:not([style='display:none'])", :count => bob.projects.count do
      bob.projects.each do |project|
        assert_select "td a[href=http://test.host/projects/#{project.identifier}]", { :text => project.name }
      end
    end
  end

  def test_edit_will_display_personal_favorites
    with_first_project do |project|
      project.card_list_views.create_or_update(:view => {:name => 'view1'}, :style => 'list', :user_id => @member_user.id)
    end
    get :show, :id => @member_user.id
    assert_select 'table#global_personal_views' do
      assert_select "td", :html => "Project One"
      assert_select "td", :text => "view1"
    end
  end

  def test_edit_will_display_hmac_key_tab
    get :show, :id => @member_user.id
    assert_select 'div.tabs_pane' do
      assert_select "span", :html => "HMAC Auth Key"
    end
  end

  def test_show_will_display_slack_tab_if_slack_enabled_and_user_integration_exists
    slack_user_name = 'some-name'
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'

    MingleConfiguration.overridden_to(
        :saas_env => 'test',
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'https://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:user_integration_status)
          .returns({
                       authenticated: true,
                       user: {name: slack_user_name}
                   })
      SlackApplicationClient.any_instance.expects(:mapped_projects).returns({})

      get :show, :id => @member_user.id

      assert_select 'div.tabs_pane' do
        assert_select 'span', :html => 'Slack'
      end
      assert_select 'span.slack-user', :html => slack_user_name
    end
  end

  def test_show_will_display_slack_tab_if_slack_enabled_and_user_integration_does_not_exist
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'
    error_message = 'Some error message'

    MingleConfiguration.overridden_to(
        :saas_env => 'test',
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'https://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:user_integration_status).returns({authenticated: false})

      get :show, :id => @member_user.id, :slack_error => error_message

      assert_equal [error_message], flash[:error]

      assert_select 'div.tabs_pane' do
        assert_select 'span', :html => 'Slack'
      end

      assert_select 'div.tabs_content' do
        assert_select 'input.ok[value=Link Slack Account]'
      end
    end
  end


  def test_show_will_not_display_slack_tab_if_slack_enabled_but_tenant_not_authorized
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'

    MingleConfiguration.overridden_to(
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED'})

      get :show, :id => @member_user.id

      assert_select 'div.tabs_pane' do
        assert_select 'span', {count: 0, html: 'Slack'}
      end
    end
  end

  def test_show_should_display_success_message_when_user_signs_into_slack_successfully
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'

    MingleConfiguration.overridden_to(
        :saas_env => 'test',
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:user_integration_status).returns({authenticated: true, user: {name: 'ptyagi'}})

      get :show, :id => @member_user.id, :slack_user_name => 'ptyagi'

      assert_equal 'You have successfully signed in as ptyagi', flash[:notice]
    end
  end

  def test_show_should_list_all_the_projects_in_slack_notification_subscription_table_when_user_is_account_is_linked_with_slack
    logout
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'
    # project = Project.first
    user = Project.first.users.first
    login(user)
    MingleConfiguration.overridden_to(
        :saas_env => 'test',
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:user_integration_status).returns({authenticated: true, user: {name: 'ptyagi'}})
      SlackApplicationClient.any_instance.expects(:mapped_projects).returns({mappings: [{mingleTeamId: user.projects.first.team.id}]})


      get :show, :id => user.id, :slack_user_name => 'ptyagi'
      assert_select 'table#slack-notification-subscription'
      assert_select "#slack_murmur_subscription_#{user.projects.first.id}[type=checkbox][checked=checked]"
    end
  end


  def test_show_should_not_list_projects_in_slack_notification_subscription_table_when_user_is_account_is_not_linked_with_slack
    ENV['AWS_ACCESS_KEY_ID'] = 'fake_access_key_id'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'fake_secret_access_key'
    MingleConfiguration.overridden_to(
        :saas_env => 'test',
        :slack_app_url => 'https://slackserver.com',
        :app_namespace => 'authorized-tenant',
        :slack_encryption_key => 'kkCSxzaucrCTn0GK/MEH7Q==') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})
      SlackApplicationClient.any_instance.expects(:user_integration_status).returns({authenticated: false})

      get :show, :id => @member_user.id, :slack_user_name => 'ptyagi'
      assert_select 'table#slack-notification-subscription', :count => 0

    end
  end

  def test_last_login_at_set_for_users_who_login_with_cas_and_ldap
    logout
    Authenticator.authentication = TestCasLdapAuthenticatorStub.new
    post :login, :user => {:login => "sparkles", :password => MINGLE_TEST_DEFAULT_PASSWORD}
    assert_not_nil User.find_by_login('sparkles').login_access.last_login_at
  end

  def test_change_password_button_is_rendered_if_authenticator_supports_password_change
    Authenticator.authentication = ExternalAuthenticationWithPasswordRecoveryAndPasswordChange.new
    get :show, :id => @member_user
    assert_response :ok
    assert_select "a.change-password"
  end

  def test_change_password_button_is_not_rendered_if_authenticator_does_not_support_password_change
    Authenticator.authentication = ExternalAuthenticationWithNoPasswordRecoveryAndPasswordChange.new
    get :show, :id => @member_user
    assert_response :ok
    assert_select "a.change-password", :count => 0
  end

  def test_should_not_login_system_user
    logout
    User.create_or_update_system_user(:login => "systemuser", :name => 'system', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :activated => true)
    post :login, :user => { :login => 'systemuser', :password => MINGLE_TEST_DEFAULT_PASSWORD}
    assert_template 'users/login'
  end

  def test_should_be_able_to_login_mingle_configured_system_user
    requires_jruby do
      logout
      begin
        java.lang.System.setProperty('mingle.systemUser', 'systemuser')
        User.create_or_update_system_user(:login => "systemuser", :name => 'system', :password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD, :activated => true)
        post :login, :user => { :login => 'systemuser', :password => MINGLE_TEST_DEFAULT_PASSWORD}
        assert_response :redirect
      ensure
        java.lang.System.clearProperty('mingle.systemUser')
      end
    end
  end

  def test_update_api_key_returns_csv_with_key_pair
    post :update_api_key, :id => @member_user.id
    assert_response :ok
    assert_match @member_user.reload.api_key, @response.body
    assert_match "access_key_id,secret_access_key", @response.body
    assert_false @member_user.reload.api_key.include?("\n")
  end

  def test_should_redirect_to_login_when_anonymous_user_accesses_show_page
    register_license(:expiration_date => '3008-07-13', :allow_anonymous => true)
    logout
    get :show
    assert_redirected_to login_url
    set_anonymous_access_for(Project.first, true)
    get :show
    assert_redirected_to login_url
  end

  def test_should_not_record_site_activity_for_non_auth_actions
    @member_user.login_access.update_attribute(:last_login_at, nil)
    get :login
    assert_nil @member_user.login_access.last_login_at
    get :forgot_password
    assert_nil @member_user.login_access.last_login_at
  end

  def assert_no_cookie(name)
    assert(!@response.cookies.key?(name.to_s) || @response.cookies[name.to_s].nil? || @response.cookies[name.to_s].empty?)
  end

  def assert_cookie(name)
    assert(@response.cookies[name.to_s])
  end

  def logout
    logout_as_nil
  end

  def fake_session
    session_id = "1234567"
    @request.session_options[:id] = session_id
    Session.create!(:session_id => session_id, :data => "")
  end
end

class TestCasLdapAuthenticatorStub
  def authenticate?(params,request_url)
    User.new(:name => "coruscating user", :login => "sparkles", :email => nil, :version_control_user_name => "sparky")
  end

  def supports_password_recovery?
    false
  end

  def supports_password_change?
    false
  end

  def is_external_authenticator?
    true
  end
end

class ExternalAuthenticationWithNoPasswordRecoveryAndPasswordChange
  def authenticate?(controller)
    true
  end

  def supports_password_recovery?
    false
  end

  def supports_password_change?
    false
  end

  def is_external_authenticator?
    true
  end

  def managing_user_profile?
    true
  end

  def label
    self.class.name
  end
end

class ExternalAuthenticationWithPasswordRecoveryAndPasswordChange
  def authenticate?(controller)
    true
  end

  def supports_password_recovery?
    true
  end

  def supports_password_change?
    true
  end

  def is_external_authenticator?
    true
  end

  def managing_user_profile?
    true
  end

  def label
    self.class.name
  end
end
