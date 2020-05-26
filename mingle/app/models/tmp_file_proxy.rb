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

class TmpFileProxy
  def initialize(path_parts=[], options = { :write_mode => 'w' })
    @path_parts, @write_mode = path_parts, options[:write_mode]
  end
  
  def dirname
    File.dirname(pathname)
  end
  
  def basename
    File.basename(pathname)
  end
  
  def exists?
    File.exists?(pathname)
  end
  
  def read
    if File.exists?(pathname)
      File.read pathname
    else
      ActiveRecord::Base.logger.error "#read is trying to read a non-existent file '#{pathname}'."
      ''
    end
  end
  
  def readlines
    if File.exists?(pathname)
      File.readlines pathname
    else
      ActiveRecord::Base.logger.error "#readlines is trying to read a non-existent file '#{pathname}'."
      []
    end
  end
  
  def write(content)
    FileUtils.mkdir_p File.dirname(pathname) unless File.exist?(File.dirname(pathname))
    File.open(pathname, @write_mode) { |f| f.write(content) }
  rescue => e
    raise "Rescue error #{e.message} on #{pathname.inspect} and dir: #{File.dirname(pathname).inspect}"
  end
  
  def touch
    write('')
  end
  
  def delete
    File.delete(pathname) if File.exists?(pathname)
  end
end
