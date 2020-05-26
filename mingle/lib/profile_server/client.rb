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
  class Client
    def initialize(server_url, namespace, http)
      @server_url = server_url
      @namespace = namespace
      @http = http
    end

    def sync_user(user)
      with_retry do
        @http.post(sync_url,
                   :body => user_to_json(user),
                   :headers => {
                     'Content-Type' => 'application/json',
                     'Content-Length' => user_to_json(user).bytesize })
      end
    end

    def deactivate_users(params)
      body = params.to_json
      with_retry do
        @http.post(deactivate_users_url,
                   :body => body,
                   :headers => {
                     'Content-Type' => 'application/json',
                     'Content-Length' => body.bytesize })
      end
    end

    def delete_user(user)
      with_retry do
        @http.delete(delete_user_url(user),
                     :headers => { 'Content-Type' => 'application/json' })
      end
    end

    def update_saml_metadata(metadata)
      with_retry do
        @http.put("#{@server_url}/organizations/#{organization}/sso_config.json",
                  :body => organization_json(metadata),
                  :headers => {
                     'Content-Type' => 'application/json',
                     "Content-Length" => organization_json(metadata).bytesize
                   })
      end
    end

    def get_saml_metadata
      with_retry do
        code, body, _ = @http.get("#{@server_url}/organizations/#{organization}/sso_config.json",
                                  :header => {
                                    'Content-Type' => 'application/json'
                                  })
        body
      end
    end

    def update_organization(data)
      with_retry do
        @http.put("#{@server_url}/organizations/#{organization}.json",
                  :body => {:organization => data}.to_json,
                  :headers => {
                     "Content-Type" => "application/json"
                   })
      end
    end

    def license_details
      with_retry do
        code, body, _ = @http.get("#{@server_url}/organizations/#{organization}.json",
                                  :headers => {
                                    'Content-Type' => 'application/json'
                                  })
        JSON.parse(body)
      end
    end

    def update_last_data_exported_on(timestamp)
      with_retry do
        @http.post("#{@server_url}/organizations/#{organization}/last_data_exported_on.json",
                   :body => {timestamp: timestamp}.to_json,
                   :headers => {'Content-Type' => 'application/json'})
      end
    end

    def sso_by_idp?
      data = get_saml_metadata
      data.present? && data != 'null'
    end

    def cas_login_url(service)
      "#{@server_url}/cas/#{organization}/login?service=#{service}"
    end

    def cas_logout_url(service)
      "#{@server_url}/cas/#{organization}/logout?url=#{service}"
    end

    def cas_ticket_validate(ticket, service)
      code, body = @http.get(cas_validate_url(ticket, service))

      answer, login = body.split("\n")

      unless ['yes', 'no'].include?(answer)
        log_error(nil, "The profile server did not respond correctly , response is :\n #{body}")
        return
      end
      [answer, login]
    rescue StandardError => e
      log_error(e, "The profile server did not respond correctly", :force_full_trace => true)
    end

    private

    def with_retry(&block)
      sleeping = Rails.env.test? ? 0 : lambda { |tries| (tries + 1) * (tries + 1) }
      retryable({:on => NetworkError, :tries => 4, :sleep => sleeping }, &block)
    end

    def organization_json(saml_metadata)
      {
        :organization => {
          :saml_metadata => saml_metadata
        }
      }.to_json
    end
    def user_to_json(user)
      {:user => {
          :name => user.name,
          :login => user.login,
          :password_hash => user.password,
          :password_salt => user.salt,
          :active => user.activated,
          :email => user.email,
          :last_login_at => user.login_access.try(:last_login_at)
        }}.to_json
    end

    def sync_url
      "#{@server_url}/organizations/#{organization}/users/sync.json"
    end

    def deactivate_users_url
      "#{@server_url}/organizations/#{organization}/users/deactivate.json"
    end

    def cas_validate_url(ticket, service)
      "#{@server_url}/cas/#{organization}/validate?ticket=#{ticket}&service=#{service}"
    end

    def delete_user_url(user)
      "#{@server_url}/organizations/#{organization}/users/destroy_by_login.json?login=#{user.login}"
    end

    def organization
      app_namespace = MingleConfiguration.app_namespace
      @namespace.blank? ? app_namespace : "#{@namespace}$#{app_namespace}"
    end
  end
end
