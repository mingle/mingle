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

if !MingleConfiguration.profile_server_url.blank?
  options = {
      :url => MingleConfiguration.profile_server_url,
      :namespace => MingleConfiguration.profile_server_namespace,
      :access_key_id => MingleConfiguration.profile_server_access_key_id,
      :access_secret_key => MingleConfiguration.profile_server_access_secret_key,
      :skip_ssl_verification => MingleConfiguration.profile_server_skip_ssl_verification?
  }
  ProfileServer.configure(options)


  MinglePlugins::Authenticators.register(ProfileServer.authentication)
end
