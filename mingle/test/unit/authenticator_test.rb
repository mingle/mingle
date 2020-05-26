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

# Tags: user, authenticator
class AuthenticatorTest < ActiveSupport::TestCase
  class SimpleExternalAuthenticatorAuthenticator < MingleDBAuthentication
    def users
      @users ||= []
    end

    def exists?(login, password)
      users.include?("#{login}:#{password}")
    end

    def authenticate?(params, request_url)
      login = params[:user][:login]
      password = params[:user][:password]
      if exists?(login, password)
        User.find_by_login(login) || User.new(:login => login, :name => "#{login} name", :password => password)
      end
    end
    
    def label
      "simple"
    end
  end

  def setup
    @authenticator = SimpleExternalAuthenticatorAuthenticator.new
    Authenticator.authentication = @authenticator
  end

  def teardown
    Authenticator.authentication = nil
  end
  
  def test_setup_authenticator_correctly
    assert_equal "simple", Authenticator.label
  end
  
  def test_by_default_authenticator_are_managing_user_profile_locally
    assert_false Authenticator.managing_user_profile_externally?
  end

  def test_authenticate
    @authenticator.users << "admin:password"
    assert Authenticator.authenticate?({:user => {:login => 'admin', :password => 'password'}}, '')
    assert_nil Authenticator.authenticate?({:user => {:login => 'notexist', :password => 'password'}}, '')
  end

  def test_should_auto_enroll_user_who_login_success_but_is_not_exist_in_mingle
    @authenticator.users << "someone_not_in_mingle:password"
    user = Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    assert user
    assert_equal 'someone_not_in_mingle', user.login
    assert_equal 'someone_not_in_mingle name', user.name
    assert User.find_by_login('someone_not_in_mingle')
  end

  #bug #13500
  def test_auto_enroll_failed_when_there_is_project_is_enabled_auto_enroll_and_contains_a_mql_filter_view_using_user_property_with_current_user
    login_as_member
    with_first_project do |project|
      view = project.card_list_views.create_or_update(:view => { :name => "team fav" }, :filters => {:mql => 'dev is current user'})
      project.update_attribute(:auto_enroll_user_type, 'full')
    end
    logout_as_nil

    @authenticator.users << "someone_not_in_mingle:password"
    user = Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    assert user
    assert User.find_by_login('someone_not_in_mingle')
  end


  def test_should_generate_random_password_for_auto_enroll_user
    @authenticator.users << "someone_not_in_mingle:password"
    user = Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    assert_not_equal 'password', user.password
  end

  def test_created_auto_enroll_user_should_pass_strict_password_validation
    format = Authenticator.password_format
    begin
      Authenticator.password_format = 'strict'
      @authenticator.users << "someone_not_in_mingle:password"
      user = Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
      assert user.password
    ensure
      Authenticator.password_format = format
    end
  end

  def test_should_not_auto_enroll_user_as_admin_as_default
    @authenticator.users << "someone_not_in_mingle:password"
    user = Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    assert !user.admin?
  end

  def test_should_be_able_to_auto_enroll_user_as_admin
    Authenticator.auto_enroll_as_mingle_admin = true
    @authenticator.users << "someone_not_in_mingle:password"
    user = Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    assert user.admin?
  ensure
    Authenticator.auto_enroll_as_mingle_admin = false
  end

  def test_should_not_be_able_to_enroll_user_when_hits_license_limitation
    register_license(:max_light_users => User.activated_light_users, :max_active_users => User.activated_full_users)
    assert CurrentLicense.registration.max_active_full_users_reached?
    @authenticator.users << "someone_not_in_mingle:password"
    assert_raise CreateFullUserWhileFullUserSeatsReachedException do
      Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    end
  end

  def test_should_raise_invalid_authenticate_implementation_error_if_authenticator_returns_a_user_object_without_login_or_name
    def @authenticator.authenticate?(params, request_url)
      User.new(:login => 'login')
    end
    assert_raise Authenticator::InvalidAuthenticateImplementationError do
      Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    end

    def @authenticator.authenticate?(params, request_url)
      User.new(:name => 'name')
    end
    assert_raise Authenticator::InvalidAuthenticateImplementationError do
      Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
    end
  end

  def test_should_be_able_to_turn_off_auto_enroll
      Authenticator.auto_enroll = false
      @authenticator.users << "someone_not_in_mingle:password"
      user = Authenticator.authenticate?({:user => {:login => 'someone_not_in_mingle', :password => 'password'}}, '')
      assert_nil user
  ensure
    Authenticator.auto_enroll = true
  end
end
