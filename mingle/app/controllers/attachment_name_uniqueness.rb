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

module AttachmentNameUniqueness
  def ensure_unique_filename_in_project(filename, project)
    filename = FileColumn::sanitize_filename(filename)

    if (project.attachments.count(:conditions => ["#{Project.connection.quote_column_name("file")} = ?", filename]) > 0)
      filename = unique_filename(filename)
    end
    filename
  end

  def unique_filename(filename)
    # tarballs are special
    ext = filename.downcase.end_with?(".tar.gz") ? ".tar.gz" : File.extname(filename)

    basename = File.basename(filename, ext)
    [basename, "-#{UUID.generate(:compact)[1..6]}", ext].join
  end
end
