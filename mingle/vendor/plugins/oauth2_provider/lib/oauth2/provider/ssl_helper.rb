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
    module SslHelper

      def self.included(controller_class)
        controller_class.before_filter :mandatory_ssl unless ENV['DISABLE_OAUTH_SSL']
      end

      protected
      def mandatory_ssl
        if !request.ssl?
          if !ssl_enabled?
            error = 'This page can only be accessed using HTTPS.'
            flash.now[:error] = error
            render(:text => '', :layout => true, :status => :forbidden)
            return false
          else
            redirect_to params.merge(ssl_base_url_as_url_options)
            return false
          end
        end
        true
      end

      private

      def ssl_base_url_as_url_options
        Oauth2::Provider::Configuration.ssl_base_url_as_url_options
      end

      def ssl_base_url
        Oauth2::Provider::Configuration.ssl_base_url
      end

      def ssl_enabled?
        !ssl_base_url.blank? && ssl_base_url_as_url_options[:protocol] == 'https'
      end
    end
  end
end
