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
require 'lib/build/transport'

namespace :cruise do
  
  def read_from_user_input(lable)
    print "[#{lable}]: "
    STDOUT.flush
    STDIN.gets.chop!
  end

  def echo_off
    system "stty -echo" 
    ret = yield
    puts
    ret
  ensure
    system "stty echo"
  end
  
  class RemoteAgents
    def initialize
      @user = ENV['ADUSER'] || read_from_user_input("Your AD service user name")
      @password = ENV['ADPASS'] || echo_off { read_from_user_input("Your AD service password") }
      @builds = ENV['BUILD'] || read_from_user_input("build agent number (separated by ',')")    
      @location = ENV['LOCATION'] || read_from_user_input("agent name prefix (like bjstdmngbgr)")    
    end
    
    def sudo(*commands)
      @builds.to_s.split(',').each do |build|
        machine = "#{@location}#{build}.thoughtworks.com"
        begin
          ssh = Mingle::Ssh.new(machine, @user, @password)
          commands.each do |command|
            puts "on #{machine} executing: #{command}"
            ssh.executeCommand "echo '#{@password}' | sudo -S #{command}"
            puts "finished: #{command}"
          end
        rescue  StandardError => e
          puts "execution failed for #{machine}: #{e}"
          next
        end
      end
    end
  end

  
  desc "reboot remote build machines, usage is like rake cruise:reboot_remote_build ADUSER=wpc ADPASS=wpcpass BUILD=32,26"
  task :reboot_remote_build do
    RemoteAgents.new.sudo "reboot"
  end
  
  desc "change cruise server to all agents"
  task :change_cruise_server do
    old_cruise_sever = ENV['OLD_CRUISE_SERVER'] || read_from_user_input("OLD cruise server")
    new_cruise_sever = ENV['NEW_CRUISE_SERVER'] || read_from_user_input("New cruise server")
    RemoteAgents.new.sudo "sed s/#{old_cruise_sever}/#{new_cruise_sever}/ /etc/default/cruise-agent >~/cruise-agent.new", 
        "mv ~/cruise-agent.new /etc/default/cruise-agent",
        "/etc/init.d/cruise-agent restart"
  end
end