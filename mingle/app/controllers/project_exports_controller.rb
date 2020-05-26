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

class ProjectExportsController < ProjectAdminController
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  allow :get_access_for => [:confirm_as_template, :confirm_as_project, :download]
  privileges UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => ["confirm_as_project", "confirm_as_template"]

  def confirm_as_project
    render :template => 'project_exports/confirm', :locals => { :export_as_template => false }
  end

  def confirm_as_template
    render :template => 'project_exports/confirm', :locals => { :export_as_template => true }
  end

  def create
    publisher = ProjectExportPublisher.new(@project, User.current, params[:export_as_template] == true.to_s)
    publisher.publish_message
    @asynch_request = publisher.asynch_request
    flash.now[@asynch_request.info_type] = @asynch_request.progress_msg
    projects_edit_action = { :controller => 'projects', :action => 'edit' }
    close_url = authorized?(projects_edit_action) ? projects_edit_action : {:controller => 'team', :action => 'index'}
    render_in_lightbox 'asynch_requests/progress', :locals => { :close_url => close_url, :deliverable => @project }
  end

  def download
    @asynch_request = AsynchRequest.find(params[:id])
    absolute_filepath = @asynch_request.filename
    send_file absolute_filepath, :filename => @asynch_request.exported_file_name, :type => 'application/octet-stream'
  end

  def always_show_sidebar_actions_list
    ['confirm_as_project', 'confirm_as_template']
  end
end
