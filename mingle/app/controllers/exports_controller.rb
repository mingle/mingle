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

class ExportsController < ApplicationController

  include RunningExportsHelper

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN => [:create, :download],
             UserAccess::PrivilegeLevel::REGISTERED_USER => [:index]
  before_filter :ensure_exports_enabled

  def index
    respond_to do |format|
      format.html do
        @users_count = User.count
        @admins_count = MemberRole.all_project_admins.count
        @user_icons_count = User.count(:icon)
        @projects = Project.all_sorted_based_on_last_activity
        @programs = Program.all_sorted_based_on_last_activity
        @dependencies_count = Dependency.count
        @export = Export.last
        @export_config = !@export.nil? && @export.status == Export::IN_PROGRESS ? @export.config : {:all_users_and_projects_admins => true, :user_icons => true}
        render :index
      end
      format.json do
        export = Export.find(params[:id])
        render json: export.to_json
      end
    end
  end

  def create
    export = Export.last
    if export.nil? || export.status != Export::IN_PROGRESS
      export = Export.create(status: Export::IN_PROGRESS, config: params.except(:controller, :action), user: User.current)
      add_monitoring_event('export_started', {'site_name' => active_tenant.name}) if MingleConfiguration.saas? && active_tenant
      export.start
    end
    render json: export.to_json
  end

  def download
    export = Export.find(params[:export_id])
    add_monitoring_event('download_started', {'site_name' => active_tenant.name}) if MingleConfiguration.saas? && active_tenant
    if MingleConfiguration.use_s3_tmp_file_storage?
      absolute_filepath = export.export_file_download_url(nil, nil, {})
      redirect_to absolute_filepath
    else
      absolute_filepath = export.export_file
      send_file absolute_filepath, :type => 'application/octet-stream'
    end
  end

  def delete
    export = Export.last
    if  export.status != Export::COMPLETED
      export.destroy
      update_running_exports
    end
   render json: Export.last.to_json
  end

  private
  def active_tenant
    Multitenancy.active_tenant
  end

  def ensure_exports_enabled
    raise InvalidResourceError, FORBIDDEN_MESSAGE unless MingleConfiguration.export_data? || MingleConfiguration.installer?
  end
end
