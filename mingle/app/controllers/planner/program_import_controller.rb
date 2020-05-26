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

class ProgramImportController < ApplicationController
  ERROR_MSGS = {
    :missing => "Export file must be uploaded",
    :bad_extension => "File must have either a '.program' or a '.plan' extension",
    :corrupted => "The export file appears to be corrupt",
    :unzip_failure => "Invalid export file"
  }
  allow :get_access_for => [:new]

  privileges UserAccess::PrivilegeLevel::MINGLE_ADMIN=>["import", "new"]

  before_filter :validate_upload_file, :only => :import

  def new
    if MingleConfiguration.disable_import_program?
      flash[:info] = 'Importing a program has been temporarily disabled. Please try again later.'
      redirect_to :controller => 'programs', :action => 'index'
    end
  end

  def import
    publisher = ProgramImportPublisher.new(User.current, params['import'])
    if publisher.valid_message?
      publisher.publish_message
      asynch_request = publisher.asynch_request
      redirect_to :controller => 'asynch_requests', :action => 'progress', :id => asynch_request.id
    else
      flash.now[:error] = publisher.validation_errors
      render :action => :new
    end
  rescue Zipper::InvalidZipFile => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
    flash.now[:error] = ERROR_MSGS[:unzip_failure]
    render :action => :new
  rescue  => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
    flash.now[:error] = ERROR_MSGS[:corrupted]
    render :action => :new
  end

  private

  def is_program_export?(file_to_import)
    File.extname(file_to_import.original_filename) =~ /\.(plan|program)$/
  end

  def validate_upload_file
    file_to_import = params['import']
    if file_to_import.blank?
      redirect_with_error ERROR_MSGS[:missing]
    elsif !is_program_export?(file_to_import)
      redirect_with_error ERROR_MSGS[:bad_extension]
    end
  end

  def redirect_with_error(message)
    flash[:error] = message
    redirect_to :action => :new
  end

end
