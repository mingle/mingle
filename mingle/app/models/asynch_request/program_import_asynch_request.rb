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

class ProgramImportAsynchRequest < AsynchRequest
  validate_on_create :validate_tmp_file_size

  def progress_msg
    if completed? && success?
      "Program import complete."
    else
      self.error_details.unshift(progress_message).compact.join("<br/>").html_safe
    end
  end

  def callback_url(params, project)
    {:controller => 'asynch_requests', :action => 'progress', :id => id}
  end

  def success_url(controller, params)
    program = Program.find_by_identifier(deliverable_identifier)
    {:controller => 'plans', :action => 'show', :program_id => program.identifier}
  end
  
  def failed_url(controller, params)
    {:controller => 'program_import', :action => 'new' }
  end

  def view_header
    "asynch_requests/program_import_view_header"
  end
  
end
