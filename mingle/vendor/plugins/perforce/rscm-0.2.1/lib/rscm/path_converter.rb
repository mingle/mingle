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

require 'fileutils'
require 'rscm/logging'

WIN32 = RUBY_PLATFORM == "i386-mswin32"
CYGWIN = RUBY_PLATFORM == "i386-cygwin"
WINDOWS = WIN32 || CYGWIN

# TODO: change to override IO.popen, using that neat trick we
# used in threadfile.rb (which is now gone)
def safer_popen(cmd, mode="r", expected_exit=0, &proc)
  Log.info "Executing command: '#{cmd}'"
  ret = IO.popen(cmd, mode, &proc)
  exit_code = $? >> 8
  raise "#{cmd} failed with code #{exit_code} in #{Dir.pwd}. Expected exit code: #{expected_exit}" if exit_code != expected_exit
  ret
end

def with_working_dir(dir)
  # Can't use Dir.chdir{ block } - will fail with multithreaded code.
  # http://www.ruby-doc.org/core/classes/Dir.html#M000790
  #
  prev = Dir.pwd
  begin
    dir = File.expand_path(dir)
    Log.info "Making directory: '#{dir}'"
    FileUtils.mkdir_p(dir)
    Dir.chdir(dir)
    Log.info "In directory: '#{dir}'"
    yield
  ensure
    Dir.chdir(prev)
  end
end

# Utility for converting between win32 and cygwin paths. Does nothing on *nix.
module RSCM
  module PathConverter
    def filepath_to_nativepath(path, escaped)
      return nil if path.nil?
      path = File.expand_path(path)
      if(WIN32)
        path.gsub(/\//, "\\")
      elsif(CYGWIN)
        cmd = "cygpath --windows #{path}"
        safer_popen(cmd) do |io|
          cygpath = io.read.chomp
          escaped ? cygpath.gsub(/\\/, "\\\\\\\\") : cygpath
        end
      else
        path
      end
    end

    def filepath_to_nativeurl(path)
      return nil if path.nil?
      if(WINDOWS)
        urlpath = filepath_to_nativepath(path, false).gsub(/\\/, "/")
        "file:///#{urlpath}"
      else
        "file://#{File.expand_path(path)}"
      end
    end

    def nativepath_to_filepath(path)
      return nil if path.nil?
      if(WIN32)
        path.gsub(/\//, "\\")
      elsif(CYGWIN)
        path = path.gsub(/\\/, "/")
        cmd = "cygpath --unix #{path}"
        safer_popen(cmd) do |io|
          io.read.chomp
        end
      else
        path
      end
    end
    
    def ensure_trailing_slash(url)
      return nil if url.nil?
      if(url && url[-1..-1] != "/")
        "#{url}/"
      else
        url
      end
    end

    module_function :filepath_to_nativepath
    module_function :filepath_to_nativeurl
    module_function :nativepath_to_filepath
    module_function :ensure_trailing_slash
  end
end
