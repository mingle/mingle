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

class DualAppServer
  TEST_JAVA_OPTS = %w(jruby.compat.version mingle.noCleanup mingle.siteURL mingle.secureSiteURL
                      jruby.max.runtimes jruby.min.runtimes)
  def initialize(system_properties)
    @system_properties = system_properties.slice(*TEST_JAVA_OPTS)
    @system_properties['MINGLE'] = 'acceptance'
  end

  def start
    puts "Starting dual app server with env: #{env_variables.inspect}"
    raise 'dual_server.sh execution failed' unless system(env_variables, 'script/dual_server.sh start > dual_server.exec.out 2>&1')
    puts 'Starting dual app server'
  end


  def stop
    puts 'Stopping dual app server'
    system('script/dual_server.sh stop')
  end

  def getStatus
    sleep 20
    'started'
  end

  private
  def env_variables
    puts "JAVA_OPTS : #{java_opts}"
    {
        'TEST_JAVA_OPTS' => java_opts,
        'BUILD_SELENIUM_WEB_XML' => 'true',
        'BUILD_DUAL_APP' => 'true',
        'BUILD_RAILS_5_WAR' => ENV["BUILD_RAILS_5_WAR"],
        'BUILD_ROOT_WAR' => ENV["BUILD_ROOT_WAR"],
        'RAILS_ENV' => 'test'
    }
  end

  def java_opts
      @system_properties.map{|propName, propValue| "-D#{propName}='#{propValue}'"}.join(' ')
    end
end
