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
  class InvalidZipFile < StandardError
  end
  
  def zip(basedir)
    zip_file = "#{basedir}.zip"
    system("cd '#{File.expand_path(basedir)}' && zip -r '#{File.expand_path(zip_file)}' . 2>&1 > /dev/null")
    raise "Could not create zip file: #{zip_file}" unless File.exist?(zip_file)
    zip_file
  end
  
  def unzip(zip_file, to_dir)
    system("unzip '#{zip_file}' -d '#{to_dir}' 2>/dev/null >/dev/null")
    raise InvalidZipFile, "This is not a valid zip file, zip file: #{zip_file}, to dir: #{to_dir}" if $? != 0
  end
end
