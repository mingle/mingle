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

class LicenseController < ApplicationController
  allow :get_access_for => [:show, :warn, :clear_cached_license_status]
  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN=>["show", "update"]
  skip_before_filter :check_license_expiration, :only => [:warn, :dismiss_expiration_warning]
  def show
    @registration = CurrentLicense.registration
    @license_key = CurrentLicense.license_key
    render :template => 'license/show.rhtml'
  end

  def update
    status = CurrentLicense.register!(params[:license_key].strip, params[:licensed_to])
    if status.valid?
      recheck_license_on_next_request
      flash[:notice] = "License was registered successfully"
      redirect_to :action => :show, :disable_registration => true
    else
      set_rollback_only
      flash.now[:error] = 'License data is invalid'
      show
    end
  end

  def ask_for_upgrade
    add_monitoring_event('upgrade_requested')
    InviteToTeamMailer.deliver_ask_for_upgrade(:requester => User.current)
    render 'team/invite_to_team_thanks', :layout => false
  end

  def warn
    render :layout => false, :action => 'warn'
  end

  def dismiss_expiration_warning
    session['license_expiration_warning_dismissed'] = true
    redirect_back_or_default(User.current)
  end

  def clear_cached_license_status
    CurrentLicense.clear_cached_license_status!
    head :no_content
  end
end
