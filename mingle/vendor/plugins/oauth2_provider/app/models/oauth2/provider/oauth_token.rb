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
    class OauthToken < ModelBase

      columns :user_id, :oauth_client_id, :access_token, :refresh_token, :expires_at => :integer

      EXPIRY_TIME = 90.days

      def oauth_client
        OauthClient.find_by_id(oauth_client_id)
      end

      def access_token_attributes
        {:access_token => access_token, :expires_in => expires_in, :refresh_token => refresh_token}
      end

      def expires_in
        (Time.at(expires_at.to_i) - Clock.now).to_i
      end

      def expired?
        expires_in <= 0
      end

      def refresh
        self.destroy
        oauth_client.create_token_for_user_id(user_id)
      end

      def before_create
        self.access_token = ActiveSupport::SecureRandom.hex(32)
        self.expires_at = (Clock.now + EXPIRY_TIME).to_i
        self.refresh_token = ActiveSupport::SecureRandom.hex(32)
      end

    end
  end
end
