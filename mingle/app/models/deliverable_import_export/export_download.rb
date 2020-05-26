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

class ExportDownload
  def initialize(temporary_directory, progress, export_file)
    @progress = progress
    @temporary_directory = temporary_directory
    @export_file = export_file
  end
  
  def zip_temp_files_and_copy_to_swap_dir
    zip_filename = @temporary_directory.zip
    FileUtils.mkdir_p File.dirname(@export_file.pathname)
    FileUtils.mv(zip_filename, @export_file.pathname)
    @progress.store_exported_filename @export_file.pathname
  end
end
