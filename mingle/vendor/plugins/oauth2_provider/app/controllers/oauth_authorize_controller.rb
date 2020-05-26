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

class OauthAuthorizeController < ::ApplicationController

  include Oauth2::Provider::SslHelper

  def index
    return unless validate_params
  end

  def authorize
    return unless validate_params

    unless params[:authorize] == 'Yes'
       redirect_to "#{params[:redirect_uri]}?error=access-denied"
      return
    end

    authorization = @client.create_authorization_for_user_id(current_user_id_for_oauth)
    state_param = if params[:state].blank?
      ""
    else
      "&state=#{CGI.escape(params[:state])}"
    end

    redirect_to "#{params[:redirect_uri]}?code=#{authorization.code}&expires_in=#{authorization.expires_in}#{state_param}"
  end

  private

  # TODO: support 'code', 'token', 'code-and-token'
  VALID_RESPONSE_TYPES = ['code']

  def validate_params
    if params[:client_id].blank? || params[:response_type].blank?
      redirect_to "#{params[:redirect_uri]}?error=invalid-request"
      return false
    end

    unless VALID_RESPONSE_TYPES.include?(params[:response_type])
      redirect_to "#{params[:redirect_uri]}?error=unsupported-response-type"
      return
    end

    if params[:redirect_uri].blank?
      render :text => "You did not specify the 'redirect_uri' parameter!", :status => :bad_request
      return false
    end

    @client = Oauth2::Provider::OauthClient.find_one(:client_id, params[:client_id])

    if @client.nil?
      redirect_to "#{params[:redirect_uri]}?error=invalid-client-id"
      return false
    end

    if @client.redirect_uri != params[:redirect_uri]
      redirect_to "#{params[:redirect_uri]}?error=redirect-uri-mismatch"
      return false
    end

    true
  end

end
