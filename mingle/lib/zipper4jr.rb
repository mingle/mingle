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

module Zipper
  class InvalidZipFile < StandardError; end

  def zip(basedir, name=nil, zip64=true)
    output_file = name || "#{basedir}.zip"
    output_stream = java.io.FileOutputStream.new(output_file)
    archive_output_stream = org.apache.commons.compress.archivers.ArchiveStreamFactory.new.createArchiveOutputStream(org.apache.commons.compress.archivers.ArchiveStreamFactory::ZIP, output_stream)
    archive_output_stream.setUseZip64(org.apache.commons.compress.archivers.zip.Zip64Mode::Always) if zip64
    Dir.chdir(basedir) do
      Dir.glob("**/*").each do |file|
        if File.directory? file
          zip_directory(archive_output_stream, file)
        else
          zip_file(archive_output_stream, basedir, file)
        end
      end
    end
    
    archive_output_stream.close
    raise "Could not create zip file '#{output_file}' from folder '#{basedir}'." unless File.exist?(output_file)
    output_file
  end

  def zip_directory(archive_output_stream, path)
    path = File.join(path, File::SEPARATOR) unless path.ends_with?(File::SEPARATOR)
    entry = org.apache.commons.compress.archivers.zip.ZipArchiveEntry.new(path)
    archive_output_stream.putArchiveEntry(entry)
    archive_output_stream.closeArchiveEntry     
  end

  def zip_file(archive_output_stream, basedir, file)
    entry = org.apache.commons.compress.archivers.zip.ZipArchiveEntry.new(file)
    archive_output_stream.putArchiveEntry(entry)
    input_stream = java.io.FileInputStream.new(File.join(basedir, file))
    org.apache.commons.io.IOUtils.copy(input_stream, archive_output_stream) unless entry.isDirectory
    input_stream.close
    archive_output_stream.closeArchiveEntry     
  end

  def unzip(zip_file, to_dir)
    input_stream = java.io.FileInputStream.new(zip_file)
    archive_input_stream = org.apache.commons.compress.archivers.ArchiveStreamFactory.new.createArchiveInputStream(org.apache.commons.compress.archivers.ArchiveStreamFactory::ZIP, input_stream)
    has_zip_entry = false
    FileUtils.mkdir_p to_dir
    while (entry = archive_input_stream.getNextZipEntry) do
      has_zip_entry = true
      file_path = File.join(to_dir, entry.getName)
      if entry.isDirectory
        FileUtils.mkdir_p(file_path) 
      else
        output_stream = java.io.FileOutputStream.new(java.io.File.new(file_path))
        org.apache.commons.io.IOUtils.copy(archive_input_stream, output_stream)
        output_stream.close
      end
    end
    archive_input_stream.close
    raise "No zip entries in file to unzip." unless has_zip_entry
  rescue => e
    raise InvalidZipFile.new("Unzip failed. This is not a valid zip file. #{e.message}. zip file: '#{zip_file}', to dir: '#{to_dir}'.")
  end
  
end
