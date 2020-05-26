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

if File.expand_path(".") =~ /\/pipelines\//
  require 'test/unit/ui/testrunnerutilities'
  require 'test/unit/ui/console/testrunner'

  class Test::Unit::UI::Console::TestRunner
    def add_fault(fault)
      @faults << fault
      output_single(fault.single_character_display, Test::Unit::UI::PROGRESS_ONLY)
      if fault.respond_to?(:exception)
        output("\n------------ #{fault.message} ------------")
        output(fault.exception.backtrace.join("\n"))
        output("------------ end -----------------------")
      end
      @already_outputted = true
    end
  end
end
