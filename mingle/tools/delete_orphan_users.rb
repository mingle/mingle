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

require File.join(File.dirname(__FILE__), 'lib/environment.rb')

# ----------
#
#  This script delete all users that are not used in any project in entire history
#
#  To execute this script, from the installation directory, run:
#  $ tools/run tools/delete_orphan_users.rb
#  
# ----------

begin
  User.first_admin
rescue 
  raise "The script requires that Mingle already be configured and have at least 1 user with full admin privileges."
end


User.with_first_admin do
  User.delete_orphan_users
end
