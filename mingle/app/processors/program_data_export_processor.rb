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

class ProgramDataExportProcessor < DataExportProcessor
  QUEUE = 'mingle.program_data_export'

  def data_exporters(_)
    [ProgramProjectExporter, ProgramTeamExporter, ObjectivesExporter, ObjectivesWorksExporter]
  end

  def export_data(data_dir_path)
    @program = Program.find(@message[:program_id])
    program_dir = SwapDir::Export.program_directory(@message[:export_id], @program)
    FileUtils.mkpath(program_dir)
    super(program_dir)
  end

  def excel_file_name
    "#{@program.export_dir_name} data"
  end
end
