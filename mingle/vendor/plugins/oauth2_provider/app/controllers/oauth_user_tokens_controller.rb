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

class OauthUserTokensController < ApplicationController

  def index
    @tokens = Oauth2::Provider::OauthToken.find_all_with(:user_id, current_user_id_for_oauth)
  end

  def revoke
    token = Oauth2::Provider::OauthToken.find_by_id(params[:token_id])
    if token.nil?
      render_not_authorized
      return
    end
    if token.user_id.to_s != current_user_id_for_oauth
      render_not_authorized
      return
    end

    token.destroy
    redirect_after_revoke
  end

  def revoke_by_admin

    if params[:token_id].blank? && params[:user_id].blank?
      render_not_authorized
      return
    end

    if !params[:token_id].blank?
      token = Oauth2::Provider::OauthToken.find_by_id(params[:token_id])
      if token.nil?
        render_not_authorized
        return
      end
      token.destroy
    else
      Oauth2::Provider::OauthToken.find_all_with(:user_id, params[:user_id]).map(&:destroy)
    end

    redirect_after_revoke
  end

  private

  def render_not_authorized
    render :text => "You are not authorized to perform this action!", :status => :bad_request
  end

  def redirect_after_revoke
    flash[:notice] = "OAuth access token was successfully deleted."
    redirect_to params[:redirect_url] || {:action => 'index'}
  end

end
