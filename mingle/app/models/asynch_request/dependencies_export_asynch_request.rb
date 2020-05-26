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
  class DependenciesExportAsynchRequest < ::AsynchRequest

    def processor_queue
      DependenciesExportProcessor::QUEUE
    end

    def callback_url(params, identifier)
      {:controller => 'asynch_requests', :action => 'progress', :id => id, :export_date => identifier}
    end

    def progress_msg
      if completed? && success?
        "Dependencies export complete. Please wait for download to begin."
      else
        "#{progress_message} (Exported #{completed} of #{total})"
      end
    end

    def export_description
      "Exporting dependencies"
    end

    def success_url(controller, params)
      if MingleConfiguration.use_s3_tmp_file_storage?
        self.tmp_file_download_url(nil, nil, :response_content_disposition => "attachment; filename=\"#{tmp_file_name}\"")
      else
        { :controller => "dependencies_import_export", :action => "download", :export_date => deliverable_identifier, :id  => id}
      end
    end

    def failed_url(controller, params); end

    def view_header
      "asynch_requests/dependencies_export_view_header"
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
      "#{deliverable_identifier}.dependencies"
    end
  end
end
