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

class ProgramExportController < PlannerApplicationController
  allow :get_access_for => [:index, :download],
        :post_access_for => [:create]

  privileges privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ["index", "create", "download"],
                        UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:index, :create, :download]

  def index
    render :index, :layout => 'application'
  end

  def create
    publisher = ProgramExportPublisher.new(@program, User.current)
    publisher.publish_message
    @asynch_request = publisher.asynch_request
    flash.now[@asynch_request.info_type] = @asynch_request.progress_msg
    render_in_lightbox 'asynch_requests/progress', :locals => { :deliverable => @program }
  end

  def download
    @asynch_request = AsynchRequest.find(params[:id])
    absolute_filepath = @asynch_request.filename
    send_file absolute_filepath, :filename => @asynch_request.exported_file_name, :type => 'application/octet-stream'
  end
end
