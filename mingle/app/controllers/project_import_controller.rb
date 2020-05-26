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

require 's3_import_policy_document'

class ProjectImportController < ApplicationController
  include AWSHelper

  allow :get_access_for => [:index, :import_from_s3, :sign_s3_upload], :redirect_to => { :action => :index }

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN=>["sign_s3_upload", "import_from_s3", "import", "index"]

  def index
    @title = "Import"
  end

  def sign_s3_upload
    string_to_sign = params["to_sign"]
    credentials = s3_multipart_upload_credentials
    encoded = Base64.encode64(
      OpenSSL::HMAC.digest(
        OpenSSL::Digest::Digest.new("sha1"),
        credentials[:secret_access_key],
        string_to_sign)).gsub("\n","")

    render :text => encoded, :status => 200
  end

  def import_from_s3
    validation_errors = validate_project_info
    s3_obj_key = MingleConfiguration.multipart_s3_import? ? params[:s3_object_key] : session[:s3_import_key]
    session[s3_obj_key] = nil
    validation_errors << "Could not find the file uploaded, please try again" if s3_obj_key.blank?
    if validation_errors.empty?
      add_monitoring_event('import_project')
      publisher = ProjectImportPublisher.new(User.current,
                                             params['project']['name'],
                                             params['project']['identifier'])

      asynch_request = publisher.publish_s3_message(s3_obj_key)
      redirect_to :controller => 'asynch_requests', :action => 'progress', :id => asynch_request.id
    else
      flash.now[:error] = validation_errors
      render :action => 'index'
    end
  end

  def import
    if params['import'].blank?
      flash[:not_found] = 'Export file must be uploaded'
      redirect_to :action => 'index'
      return
    end

    if params['import'].is_a?(String)
      flash[:not_found] = 'File upload is not supported for your browser. Please contact Mingle support for further information.'
      redirect_to :action => 'index'
      return
    end

    validation_errors = validate_project_info
    publisher = ProjectImportPublisher.new(User.current, params['project']['name'], params['project']['identifier'])

    if validation_errors.empty?
      asynch_request = publisher.publish_message(params['import'])
      redirect_to :controller => 'asynch_requests', :action => 'progress', :id => asynch_request.id
    else
      flash.now[:error] = validation_errors
      render :action => 'index'
    end
  end

  private
  def default_back_url
    projects_url
  end

  def validate_project_info
    return [] if params['project']['name'].blank? && params['project']['identifier'].blank?
    project = Project.new(:name => params['project']['name'], :identifier => params['project']['identifier'])
    project.valid?
    params['project']['name'] = project.name
    params['project']['identifier'] = project.identifier
    project.errors.full_messages
  end

end
