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

require 'rake/testtask'
require "selenium-rc"

SeleniumRC::Server
module SeleniumRC

  class Server
    # override to use smaller heap
    def start
      command = "java -Xmx256m -jar \"#{self.class.jar_path}\""
      command << " -port #{port}"
      command << " -Djava.security.egd=file:///dev/urandom"
      command << " #{args.join(' ')}" unless args.empty?
      begin
        fork do
          system(command)
          at_exit { exit!(0) }
        end
      rescue NotImplementedError
        Thread.start do
          system(command)
        end
      end
    end

    def selenium_command(command)
      Net::HTTP.get(host, "/selenium-server/driver/?cmd=#{command}", port).tap do |result|
        puts %Q{
          host: #{host.inspect}
          port: #{port.inspect}
          command: #{command.inspect}
          result: #{result.inspect}
        }
      end
    end

    # Wait start time: Wed Aug 19 14:32:58 -0700 2015, timeout: 60
    # Wait too long, Time.now: Wed Aug 19 14:33:58 -0700 2015
    def wait_for_service_with_timeout
      $stderr.print "\n"
      start_time = Time.now
      $stderr.print "Wait start time: #{start_time}, timeout: #{@timeout}\n"
      until ready?
        sleep 0.1
        now = Time.now
        if now > (start_time + @timeout)
          $stderr.print "Wait too long, Time.now: #{now}\n"
          raise ServerNotStarted.new("Selenium Server was not ready for connections after #{@timeout} seconds")
        end
      end
    end
  end
end
module SeleniumRcHelper

  # works for both GNU and BSD (e.g. MacOS X) ps
  GET_ORPHANED_SELENIUM_PIDS = %Q{ps -eopid,ppid,command | grep -F "selenium-server.jar" | grep -v grep | awk '{print $1, $2}' | tr -s " " "\n" | sort -u}
  KILL_ORPHANED_SELENIUM_PROXIES = %Q{for pid in $(#{GET_ORPHANED_SELENIUM_PIDS}); do echo "Leftover selenium pid: $pid"; kill -KILL $pid; done} # unlike xargs, will not fail when list is empty

  def root
    File.expand_path(File.join(File.dirname(__FILE__), ".."))
  end

  def log_file
    FileUtils.mkdir_p File.join(root, 'log')
    File.join(root, 'log', 'selenium_proxy.log')
  end

  def start_server
    puts "Killing any stray selenium server instances"
    system(KILL_ORPHANED_SELENIUM_PROXIES)

    # IE9 - running in multiWindow mode is the only mode that works reliably
    window_mode = ENV['SELENIUM_SERVER_WINDOW_MODE'] || '-singlewindow'
    puts "selenium window mode: #{window_mode}"
    puts "selenium server host: #{ENV["SELENIUM_SERVER_HOST"]}"
    @server = SeleniumRC::Server.boot(ENV["SELENIUM_SERVER_HOST"] || "127.0.0.1",
                                      ENV["SELENIUM_SERVER_PORT"],
                                      :args => [window_mode, "-log", log_file],
                                      :timeout => 120)
  end

  def stop_server
    puts "Attempting to stop selenium server..."
    if @server
      @server.stop
      @server = nil
    end
  end

  extend self

  class AcceptanceTestTask < Rake::TestTask
    module SeleniumRcServer
      def execute(arg)
        puts 'starting selenium proxy server'
        SeleniumRcHelper.start_server
        puts 'started'
        super
      end
    end

    def define
      super
      if task = Rake.application.lookup(@name)
        task.extend(SeleniumRcServer)
      end
    end
  end

end
