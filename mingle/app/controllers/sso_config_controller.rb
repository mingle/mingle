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

class SsoConfigController < ApplicationController
  allow :get_access_for => [:show, :edit], :redirect_to => {:action => :show}

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN  => ["show", "edit", "update"]

  before_filter :validate_toggle

  def show
    @metadata = ProfileServer.get_saml_metadata rescue nil
  end

  def edit
  end

  def update
    if file = params[:saml_metadata]
      if file.size > 100 * 1024 # 100K
        flash.now[:error] = "SAML metadata file is too big"
        render :action => 'edit'
      else
        metadata = file.read
        ProfileServer.update_saml_metadata(metadata) rescue nil
        redirect_to :action => :show
      end
    else
      ProfileServer.update_saml_metadata(nil)
      redirect_to :action => :show
    end
  end

  private
  def validate_toggle
    unless MingleConfiguration.sso_config?
      head(:not_found)
    end
  end
end
