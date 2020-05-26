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

require 'tempfile'
require 'fileutils'
require 'rscm'

module RSCM
  class Darcs < AbstractSCM
    register self

    ann :description => "Directory"
    attr_accessor :dir

    def initialize(dir=".")
      @dir = File.expand_path(dir)
    end

    def name
      "Darcs"
    end

    def create
      with_working_dir(@dir) do
        IO.popen("darcs initialize") do |stdout|
          stdout.each_line do |line|
            yield line if block_given?
          end
        end
      end
    end
    
    def import(dir, message)
      ENV["EMAIL"] = "dcontrol@codehaus.org"
      FileUtils.cp_r(Dir.glob("#{dir}/*"), @dir)
      with_working_dir(@dir) do
puts "IN::::: #{@dir}"
        cmd = "darcs add --recursive ."
puts cmd
        IO.popen(cmd) do |stdout|
          stdout.each_line do |line|
            yield line if block_given?
          end
        end
puts $?
        logfile = Tempfile.new("darcs_logfile")
        logfile.print(message)
        logfile.close
        
        cmd = "darcs record --all --patch-name \"something nice\" --logfile #{PathConverter.filepath_to_nativepath(logfile.path, false)}"
puts cmd
        IO.popen(cmd) do |stdout|
          stdout.each_line do |line|
            yield line if block_given?
          end
        end
puts $?
      end
    end

    def checkout(checkout_dir) # :yield: file
      with_working_dir(File.dirname(checkout_dir)) do
cmd = "darcs get --verbose --repo-name #{File.basename(checkout_dir)} #{@dir}"
puts cmd
        IO.popen(cmd) do |stdout|
          stdout.each_line do |line|
puts line
            yield line if block_given?
          end
        end
      end
puts $?
    end
  end
end
