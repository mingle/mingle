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

module ProfileServer
  class Authentication
    def initialize(client)
      @client = client
    end

    def sign_in_url(service)
      @client.cas_login_url(service)
    end

    def sign_out_url(service=nil)
      @client.cas_logout_url(service)
    end

    def has_valid_external_authentication_token?(params)
      !params[:ticket].blank?
    end

    def authenticate?(params, service)
      return unless has_valid_external_authentication_token?(params)
      cas_authentication(params, service)
    end

    def can_connect?
      true
    end

    def supports_password_change?
      !@client.sso_by_idp?
    end

    def supports_password_recovery?
      !@client.sso_by_idp?
    end

    def supports_login_update?
      false
    end

    def supports_basic_authentication?
      false
    end

    def is_external_authenticator?
      true
    end

    def managing_user_profile?
      false
    end

    def label
      "profile-server"
    end

    def configure(settings)
      raise 'not implementated'
    end

    private

    def cas_authentication(params, service)
      answer, login = @client.cas_ticket_validate(params[:ticket], service)
      if answer == 'yes'
        User.find_by_login(login) || new_user(login)
      end
    end

    def new_user(login)
      User.new(:name => login.downcase, :login => login.downcase).tap do |user|
        if login =~ EMAIL_FORMAT_REGEX
          user.email = login
        end
      end
    end
  end
end
