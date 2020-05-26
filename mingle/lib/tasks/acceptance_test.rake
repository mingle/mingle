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
def run_test
  system("./script/test_runner.sh test/acceptance/scenarios/cards/card_crud_test.rb")
  raise "Dual app test execution failed" if $?.exitstatus != 0
rescue => e
  puts "Error while running test : #{e.message}"
  Kernel.exit(1)
end

namespace :dual_app do
  desc 'Run acceptance test against dual app setup.'
  task :acceptance_test => [:kill_dual_app_server, 'db:test:fast_prepare_with_ssh'] do
    mkdir_p 'tmp/dual_app'
    run_test
  end

  desc 'Terminate dual_app_server'
  task :kill_dual_app_server do
    system('ps aux | grep "org\.apache\.catalina\.startup\.Bootstrap" | awk "{print $2}" | xargs kill -9')
  end
end