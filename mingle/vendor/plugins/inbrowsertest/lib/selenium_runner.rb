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

require 'test/unit/ui/console/testrunner'
require 'yaml'

module SeleniumRails

  class Runner < Test::Unit::UI::Console::TestRunner

    cattr_accessor :aut_address, :aut_port

    def self.run=(flag)
      @run = flag
    end

    def self.run?
      @run ||= false
    end

    def started(result)
      super(result)
      aut_address,aut_port = ServerStarter::RailsEnvironment.start(:startup_hooks => SeleniumRails::server_startup_hooks)
      Runner.aut_address = aut_address
      Runner.aut_port = aut_port
    end

    def finished(elapsed_time)
      super(elapsed_time)
      ServerStarter::RailsEnvironment.stop
      #Test::Unit::TestCase.close_selenium_sessions
    end
  end

end
