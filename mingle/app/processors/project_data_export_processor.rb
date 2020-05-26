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

class ProjectDataExportProcessor < DataExportProcessor
  QUEUE = 'mingle.project_data_export'

  def data_exporters(_)
    exporters = [
        ProjectTeamExporter,
        CardDataExporter,
        PageDataExporter,
        MurmurExporter,
        CardTypeExporter,
        PropertyDataExporter,
        TypeAndPropertyExporter,
        ProjectVariableExporter,
        TreeConfigurationsExporter,
        TransitionsExporter
    ]
    exporters.push(ProjectSlackIntegrationsExporter, GithubIntegrationsExporter) if MingleConfiguration.saas?
    exporters.push(CodeIntegrationExporter) if MingleConfiguration.installer?
    exporters
  end

  def export_data(data_dir_path)
    @project = Project.find(@message[:project_id])
    project_dir = SwapDir::Export.project_directory(@message[:export_id], @project)
    FileUtils.mkpath(project_dir)
    @project.with_active_project do
      super(project_dir)
    end
  end

  def excel_file_name
    "#{@project.export_dir_name} data"
  end
end
