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

class Authenticator
  # This error raised when Authenticator plugin 'authenticate?' method returns a new user object causes user save failed.
  # Must include user login and name, user password would be replaced with a random password.
  #
  # Authenticator plugin 'authenticate?' method should:
  #   1. return user model instance found in database if login success
  #   2. return a new user model instance (not save yet) if login success but could not found a user model instance in database
  #   3. return nil if login failed
  #
  class InvalidAuthenticateImplementationError < StandardError
  end

  cattr_accessor :password_format
  cattr_accessor :auto_enroll
  cattr_accessor :auto_enroll_as_mingle_admin

  self.auto_enroll = true
  self.auto_enroll_as_mingle_admin = false
  self.password_format = nil

  class << self

    delegate :supports_password_recovery?,
             :supports_password_change?,
             :supports_login_update?,
             :sign_in_url,
             :sign_out_url,
             :has_valid_external_authentication_token?,
             :label,
             :to => :standard_authentication


    def authenticate?(params,request_url)
      user = standard_authentication.authenticate?(params,request_url)
      return nil unless user
      return nil if user.system? && user.login != MingleConfiguration.system_user
      return user unless user.new_record?
      auto_enroll_user(user) if @@auto_enroll
    end

    def auto_enroll_user(user)
      if CurrentLicense.registration.max_active_full_users_reached?
        log_error(nil, "Attempted to create a full user via #{standard_authentication.class.name} when maximum user allowance has been reached")
        raise CreateFullUserWhileFullUserSeatsReachedException.new(user.login)
      end

      password = User.random_password
      if user.update_attributes :password => password, :password_confirmation => password, :admin => @@auto_enroll_as_mingle_admin
        user
      else
        e = InvalidAuthenticateImplementationError.new user.errors.full_messages.join("; ")
        log_error(e, "Unable to auto-enroll, #{standard_authentication.class.name} gave a user could not be saved. This is not an expected error.")
        raise e
      end
    end

    def authentication=(value)
      $standard_authentication = value
    end

    def strict_password_format?
      Authenticator.password_format.to_s.downcase == 'strict'
    end

    def external_login_page_unavailable?
      !use_mingle_login_page? && !can_connect?
    end
    alias_method :external_logout_unavailable?, :external_login_page_unavailable?

    def external_login_page_available?
      !use_mingle_login_page? && can_connect?
    end
    alias_method :external_logout_available?, :external_login_page_available?

    def use_mingle_login_page?
      !standard_authentication.respond_to?(:sign_in_url)
    end

    def can_connect?
      standard_authentication.respond_to?(:can_connect?) && standard_authentication.can_connect?
    end

    def invalidate_session_external_authentication_if_not_using_external_authenticator(session)
      session[:redirected_to_external_authentication] = nil if !using_external_authenticator?
    end

    def using_external_authenticator?
      standard_authentication.is_external_authenticator?
    end

    def managing_user_profile_externally?
      using_external_authenticator? && (standard_authentication.respond_to?(:managing_user_profile?) ? standard_authentication.managing_user_profile? : false)
    end

    private

    def standard_authentication
      AuthConfiguration.load unless $standard_authentication
      $standard_authentication
    end

  end
end
