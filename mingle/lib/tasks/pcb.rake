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

namespace :pcb do
  task :config do
    cp_r 'test/config/database.yml.pcb', 'config/database.yml'
  end

  task :prepare => %w(pcb:config clean_all ci:setup:testunit test:clear_svn_cache db:recreate_development db:migrate db:test:prepare)

  task :prepare_with_browser_clean => %w(pcb:prepare cruise:log_pid test:clear_browsers test:clear_hg_cache) do
    if windows?
      puts 'Clearing IE cache...'
      system('RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255')
    end
  end

  task :test => %w(pcb:prepare tlb:uf)

  task :acceptance => %w(pcb:prepare_with_browser_clean tlb:acceptance)
end


