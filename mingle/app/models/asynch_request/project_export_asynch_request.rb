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

class ProjectExportAsynchRequest < AsynchRequest

  def processor_queue
    ProjectExportProcessor::QUEUE
  end

  def callback_url(params, project)
    {:controller => 'asynch_requests', :action => 'progress', :id => id, :project_id => project.identifier}
  end

  def progress_msg
    if completed? && success?
      "#{template? ? 'Template' : 'Project'} export complete. Please wait for download to begin."
    else
      "#{progress_message} (Exported #{completed} of #{total})"
    end
  end

  def export_description
    "Exporting ".tap do |desc|
      desc << (template? ? 'Template' : 'Project')
      desc <<  " #{project.name.italic}"
    end
  end

  def project
    Project.find(self.message[:project_id])
  end

  def template?
    message[:template].to_s == 'true'
  end

  def success_url(controller, params)
    if MingleConfiguration.use_s3_tmp_file_storage?
      self.tmp_file_download_url(nil, nil, :response_content_disposition => "attachment; filename=\"#{tmp_file_name}\"")
    else
      {:controller => 'project_exports', :action => 'download', :id => id}
    end
  end

  def failed_url(controller, params); end

  def view_header
    "asynch_requests/project_export_view_header"
  end

  def exported_file_name
    self.template? ? "#{deliverable_identifier}_template.mingle" : "#{deliverable_identifier}.mingle"
  end

  def filename
    self.localize_tmp_file
  end

  def store_exported_filename(file)
    File.open(file) do |f|
      self.tmp_file = f
    end
    save!
  end
end
