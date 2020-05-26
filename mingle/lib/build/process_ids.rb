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

module Mingle
  module ProcessIds
    PID_DIR = File.expand_path File.join(File.dirname(__FILE__), '..', '..', 'tmp', 'pids')

    def self.register(name)
      FileUtils.mkdir_p PID_DIR

      File.open(pid_file(name), 'w') do |file|
        pid = Process.pid
        puts "Registering #{file.path} with pid: #{pid}"
        file.write(pid.to_s)
      end
    end

    def self.kill_all_registered_pids
      return unless File.exist?(PID_DIR)

      Dir["#{PID_DIR}/*.pid"].each do |pid_file|
        if pid = File.read(pid_file).strip
          puts "Killing #{pid_file} (pid: #{pid}"
          if Config::CONFIG['host_os'] =~ /mswin32/i || Config::CONFIG['host_os'] =~ /Windows/i
            system("taskkill /F /T /PID #{pid}") rescue nil
          else
            Process.kill(9, pid.to_i) rescue nil
          end
        end
      end
    end

    private

    def self.pid_file(name)
      FileUtils.mkdir_p(PID_DIR) unless File.exist?(PID_DIR)
      File.join(PID_DIR, "#{name}.pid")
    end
  end
end
