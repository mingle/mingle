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
require 'build/cluster'

namespace :deploy do
  $cluster = Mingle::Cluster.new(File.join(File.dirname(__FILE__) + '/cluster.yml'))

  task :stop_cluster do
    $cluster.stop
  end
  
  task :backup_database do
    # $cluster.backup_db
  end
  
  task :uninstall_mingle do
    $cluster.uninstall_mingle
  end
  
  task :download_installer do
    $cluster.download_installer
  end
  
  task :install_mingle do
    $cluster.install_mingle
  end
  
  task :configure do
    $cluster.configure
  end
  
end