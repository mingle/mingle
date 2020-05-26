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

module Oauth2
  module Provider

    ProjectApplicationController.oauth_allowed do |controller|
      %w(xml atom).include?(controller.params[:format])
    end

    OauthAuthorizeController.class_eval do
      privileges UserAccess::PrivilegeLevel::REGISTERED_USER => %w(index authorize)
    end

    OauthClientsController.class_eval do
      privileges  UserAccess::PrivilegeLevel::MINGLE_ADMIN => %w(index show destroy new create edit update)
    end

    OauthTokenController.class_eval do
      skip_filter :authorize_user_access, :check_user, :authenticated?
    end

    OauthUserTokensController.class_eval do
      privileges UserAccess::PrivilegeLevel::REGISTERED_USER => %w(index revoke), UserAccess::PrivilegeLevel::MINGLE_ADMIN => %w(revoke_by_admin)
    end

    ::Oauth2::Provider::Configuration.ssl_base_url = proc { MingleConfiguration.secure_site_url }

  end
end
