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

class ProjectImportAsynchRequest < AsynchRequest
  validate_on_create :validate_tmp_file_size

  def processor_queue
    ProjectImportProcessor::QUEUE
  end

  def callback_url(params, project)
    {:controller => 'asynch_requests', :action => 'progress', :id => id}
  end

  def template?
    message[:template].to_s == 'true'
  end

  def project_name
    message[:project_name]
  end

  def progress_msg
    if completed? && success?
      "#{progress_message} (Imported #{completed} of #{total})."
    else
      self.error_details.unshift(progress_message).compact.uniq.join("<br/>").html_safe
    end
  end

  def success_url(controller, params)
    {:controller => 'projects', :action => 'show', :project_id => deliverable_identifier}
  end

  def failed_url(controller, params)
    {:controller => 'project_import', :project_type => 'projects'}
  end

  def view_header
    "asynch_requests/project_import_view_header"
  end
end
