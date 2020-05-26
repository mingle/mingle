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

class TemplatesController < ProjectApplicationController
  #todo: these before filter need to be clean-up
  skip_before_filter :require_project_membership_or_admin
  skip_before_filter :ensure_project, :except => ['templatize', 'delete', 'confirm_delete']

  allow :get_access_for => [:new, :index, :delete], :redirect_to => { :action => :index }

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN=>["index", "new", "delete", "confirm_delete", "templatize"]
  helper :projects

  def index
    @heading = "Available Templates"
    @templates = User.current.accessible_templates.smart_sort_by(&:name)
  end

  def new
    @projects = User.current.accessible_projects.reject(&:template?)
  end

  def templatize
    template = DeliverableImportExport::ProjectExporter.export_with_error_raised(:project => @project, :template => true)
    new_project_name = Project.unique(:name, @project.name, " template")
    new_project_identifier = Project.unique(:identifier, @project.identifier, "_template")
    asynch_request = User.current.asynch_requests.create_project_import_asynch_request(new_project_identifier, nil)
    import = DeliverableImportExport::ProjectImporter.for_synchronous_import(new_project_name, new_project_identifier, template, asynch_request)
    @project = import.import
    @project = nil
    notice = "Template was successfully created"
    if request.xhr?
      html_flash.now[:notice] = "#{notice}. <a href='#{url_for(:controller => 'templates', :action => 'index', :project_id => nil)}'>View your templates</a>"
      render :update do |page|
        page['flash'].replace :partial => 'layouts/flash'
      end
    else
      flash[:notice] = notice
      redirect_to :action => 'index', :controller => 'templates'
    end
  end

  def delete #ugh
    @template_to_delete = @project
    @project = nil
  end

  def confirm_delete
    @project.destroy
    flash[:notice] = "#{@project.name} was successfully deleted"
    @project = nil
    redirect_to :action => 'index', :controller => 'templates'
  end
end
