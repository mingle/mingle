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

class Github < ActiveRecord::Base
  include HTTParty
  format :json

  belongs_to :project

  attr_accessor :secret
  validates_presence_of :username, :repository

  GITHUB_API_URL = "https://api.github.com"

  def create_webhook(mingle_post_url, user)
    ensure_api_key(user)
    @webhook_config = { "name" =>  "web",
      "active" => true,
      "events" => [ "push" ],
      "config" => {
        "url" => mingle_post_url,
        "content_type" => "json",
        "secret" => user.api_key
      }
    }

    auth_options = { "Authorization" => "token " + secret.to_s }
    @headers = auth_options.merge({"User-Agent" => 'Mingle', "Content-Type" => "application/json"})

    github_repository_url = "#{github_api_url}/repos/#{username}/#{repository}/hooks"

    response = HTTParty.post(github_repository_url, :body => @webhook_config.to_json, :headers => @headers )
    self.webhook_id = response.parsed_response['id']
    response.code
  end

  def github_api_url
    @github_api_url || GITHUB_API_URL
  end

  def github_api_url=(url)
    @github_api_url = url
  end

  def ensure_api_key(user)
    if user.api_key.nil?
      user.update_api_key
    end
  end
end
