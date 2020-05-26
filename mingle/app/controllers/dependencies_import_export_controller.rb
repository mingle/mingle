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

class DependenciesImportExportController < ApplicationController
  allow :get_access_for => [:index, :create, :download, :preview_errors, :preview]
  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN => ["index", "create", "download", "import_preview", "preview", "preview_errors", "confirm_import"]

   ERROR_MSGS = {
    :missing => "Export file must be uploaded",
    :bad_extension => "File must have a '.dependencies extension",
  }

  before_filter :validate_upload_file, :only => :import_preview
  before_filter :ensure_import_preview_asynch_request, :only => [:preview, :preview_errors, :confirm_import]

  def index
    @projects = []
    Project.all(:order => "name").each do |project|
      @projects.push(project) unless project.raised_dependencies.empty? && project.resolving_dependencies.empty?
    end
    if params[:id]
      @asynch_request = AsynchRequest.find(params[:id])
      flash[:error] = nil if @asynch_request && @asynch_request.error_views.size > 0
    end
  end

  def create
    projects = Project.find(params[:projects])
    publisher = ::DependenciesExportPublisher.new(projects, User.current)
    publisher.publish_message
    @asynch_request = publisher.asynch_request
    flash.now[@asynch_request.info_type] = @asynch_request.progress_msg
    close_url = url_for(:controller => 'dependencies_import_export', :action => 'index')
    render_in_lightbox 'asynch_requests/progress', :locals => { :close_url => close_url, :deliverable => @asynch_request.deliverable_identifier }
  end

  def download
    @asynch_request = AsynchRequest.find(params[:id])
    absolute_filepath = @asynch_request.filename
    send_file absolute_filepath, :filename => @asynch_request.exported_file_name, :type => 'application/octet-stream'
  end

  def preview
    dependencies = params[:dependencies]
    add_raising_cards_to_errors(dependencies)
  end

  def preview_errors
    redirect_to({:action => :preview, :id => params[:id]}) if @asynch_request.dependencies_errors.empty?
  end

  def import_preview
    publisher = ::DependenciesImportPreviewPublisher.new(User.current, params[:import])
    publisher.publish_message
    @asynch_request = publisher.asynch_request
    flash.now[@asynch_request.info_type] = @asynch_request.progress_msg

    redirect_to :controller => 'asynch_requests', :action => 'progress', :id => @asynch_request.id
  end

  def confirm_import
    publisher = ::DependenciesImportPublisher.new(User.current, params[:id])
    publisher.publish_message
    @asynch_request = publisher.asynch_request
    flash.now[@asynch_request.info_type] = @asynch_request.progress_msg

    redirect_to :controller => 'asynch_requests', :action => 'progress', :id => @asynch_request.id
  end

  def ensure_import_preview_asynch_request
    return head(:unprocessable_entity) if params[:id].blank?
    @asynch_request = AsynchRequest.find(params[:id])
    return head(:unprocessable_entity) if !@asynch_request.instance_of? DeliverableImportExport::DependenciesImportPreviewAsynchRequest
  end

  private

  def add_raising_cards_to_errors(dep_raising_card_params)
    return if dep_raising_card_params.blank?
    @asynch_request.dependencies_errors.map! do |dep_hash|
      dependency_number_str = dep_hash["number"].to_s
      if dep_raising_card_params.has_key?(dependency_number_str) && !dep_raising_card_params[dependency_number_str]["raising_card_number"].empty?
        dep_hash["raising_card"] = {"number" => dep_raising_card_params[dependency_number_str]["raising_card_number"].to_i,
                                    "name" => dep_raising_card_params[dependency_number_str]["raising_card_name"]}
      end
      dep_hash
    end
    @asynch_request.save!
  end

  def is_dependencies_export?(file_to_import)
    File.extname(file_to_import.original_filename) =~ /\.(dependencies)$/
  end

  def validate_upload_file
    file_to_import = params['import']
    if file_to_import.blank?
      redirect_with_error ERROR_MSGS[:missing]
    elsif !is_dependencies_export?(file_to_import)
      redirect_with_error ERROR_MSGS[:bad_extension]
    end
  end

  def redirect_with_error(message)
    flash[:error] = message
    redirect_to :action => :index
  end
end
