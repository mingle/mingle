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

module ProjectImportHelper

  def project_or_template
    params[:project_type] == 'templates' ? 'template' : 'project'
  end

  def import_file_extension
    '.mingle'
  end

  def upload_form
    MingleConfiguration.import_files_bucket_name.present? ? 's3_upload_form' : 'form'
  end

  def project_import_action_bar_attrs
    if MingleConfiguration.multipart_s3_import?
      bucket = MingleConfiguration.import_files_bucket_name
      s3key = random_s3_key
      credentials = s3_multipart_upload_credentials
      {
        "data-aws-id" => credentials[:access_key_id],
        "data-session-token" => credentials[:session_token],
        "data-bucket" => bucket,
        "data-key" => s3key,
        "data-signer-url" => url_for(:controller => :project_import, :action => :sign_s3_upload),
        "data-success-url" => url_for(:controller => :project_import, :action => :import_from_s3, :project_type => params[:project_type], :only_path => false)
      }
    else
      {}
    end
  end
end
