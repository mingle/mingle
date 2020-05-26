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
  class ProjectTemplateExporter < ProjectExporter

    def initialize(attributes={})
      super(attributes)
    end

    def export(options={})
      with_progress do
        stepped_export(ImportExport::TEMPLATE_MODELS(), :select_for_template_sql) do
          step("Exporting icons."){ IconExporter.new(@basedir).export_icons([project]) }
        end
      end
    end

    def mark_new
      self.progress.update_attributes(:total => (ImportExport::TEMPLATE_MODELS().size + 2))
      update_progress_message("Template export of project #{project.name.bold} has been queued. Please wait here for export to begin.")
      mark_queued
    end

    private

    def attachments_only_on_latest_version
      project.attachments.find_by_attachable_types([Card, Page])
    end


  end
end
