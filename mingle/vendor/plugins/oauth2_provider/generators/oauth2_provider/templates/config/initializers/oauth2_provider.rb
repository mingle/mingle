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

# Copyright (c) 2010 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the MIT License (http://www.opensource.org/licenses/mit-license.php)

module Oauth2
  module Provider

    raise 'OAuth2 provider not configured yet!'
    # please go through the readme and configure this file before you can use this plugin!

    # A fix for the stupid "A copy of ApplicationController has been removed from the module tree but is still active!"
    # error message that is caused in rails >= v2.3.3
    #
    # This error is caused because the application controller is unloaded but, the controllers in the plugin are still
    # referring to the super class that is unloaded!
    #
    # Uncommenting these lines fixes the issue, but makes the ApplicationController not reloadable in dev mode.
    #
    # if RAILS_ENV == 'development'
    #   ActiveSupport::Dependencies.load_once_paths << File.join(RAILS_ROOT, 'app/controllers/application_controller')
    # end

    # make sure no authentication for OauthTokenController
    OauthTokenController.skip_before_filter(:login_required)

    # use host app's custom authorization filter to protect OauthClientsController
    OauthClientsController.before_filter(:ensure_admin_user)

  end
end
