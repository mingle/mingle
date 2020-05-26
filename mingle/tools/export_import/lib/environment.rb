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

ENV['RAILS_ENV'] = 'production'

require File.expand_path(File.join(File.dirname(__FILE__), '../../../webapps/ROOT/WEB-INF/config/environment'))

module MingleTools
end

begin
  User.first_admin
rescue
  raise "Data directory does not contain config directory. Please provide the location of your config directory by specifying configDir in the run command." unless File.exist?(MINGLE_CONFIG_DIR)
  raise "Config directory does not contain 'database.yml' file. Make sure config directory contains valid 'database.yml' file." unless File.exist?(MINGLE_DATABASE_YML)
  raise "The script requires that Mingle already be configured and have at least one user with full admin privileges. Please make sure Mingle is already configured correctly."
end

