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

module DeliverableImportExport
  class ProgramExportAsynchRequest < ::AsynchRequest

    def processor_queue
      ProgramExportProcessor::QUEUE
    end

    def callback_url(params, program)
      {:controller => 'asynch_requests', :action => 'progress', :id => id, :program_id => program.identifier}
    end

    def progress_msg
      if completed? && success?
        "Program export complete. Please wait for download to begin."
      else
        "#{progress_message} (Exported #{completed} of #{total})"
      end
    end

    def export_description
      "Exporting program"
    end

    def success_url(controller, params)
      if MingleConfiguration.use_s3_tmp_file_storage?
        self.tmp_file_download_url(nil, nil, :response_content_disposition => "attachment; filename=\"#{tmp_file_name}\"")
      else
        program = Program.find_by_identifier(deliverable_identifier)
        { :controller => "program_export", :action => "download", :program_id => program.identifier, :id  => id}
      end
    end

    def failed_url(controller, params); end

    def view_header
      "asynch_requests/program_export_view_header"
    end

    def store_exported_filename(filename)
      File.open(filename) do |f|
        self.tmp_file = f
      end
      save!
    end

    def filename
      self.localize_tmp_file
    end

    def exported_file_name
      "#{deliverable_identifier}.program"
    end

  end
end
