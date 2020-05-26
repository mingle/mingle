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

require 'profile_server/client'
require 'profile_server/http_with_signing'
require 'profile_server/network_error'
require 'profile_server/authentication'

module ProfileServer
  class << self
    def configure(options, http=nil)
      reset
      http ||= HttpWithSigning.new(options[:access_key_id],
                                   options[:access_secret_key],
                                   options[:skip_ssl_verification])


      @client = Client.new(options[:url], options[:namespace], http)
    end

    def configured?
      @client != nil
    end

    def license_details
      @client.license_details
    end

    def update_organization(data)
      @client.update_organization(data)
    end

    def sync_user(user_record)
      @client.sync_user(user_record)
    end

    def deactivate_users(params)
      @client.deactivate_users(params)
    end

    def delete_user(user_record)
      @client.delete_user(user_record)
    end

    def update_saml_metadata(metadata)
      @client.update_saml_metadata(metadata)
    end

    def get_saml_metadata
      @client.get_saml_metadata
    end

    def sso_by_idp?
      @client.sso_by_idp?
    end

    def authentication
      Authentication.new(@client)
    end

    # test only
    def reset
      @client = nil
    end
  end
end
