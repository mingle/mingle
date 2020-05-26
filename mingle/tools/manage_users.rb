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
#  This script shows examples for managing Mingle users.
# 
#  To execute this script, from the installation directory, run:
#  $ tools/run tools/manage_users.rb
#  
# ----------

# -- create a new user

# user = User.create!(:login => 'chester', :name => 'Chester Tester', :email => 'chester@example.com', :password => 'test123!', :password_confirmation => 'test123!')

# -- make user a mingle administrator

# user = User.find_by_login('chester')
# user.update_attribute(:admin, true)


# -- add user to a project team

# user = User.find_by_login('chester')
# project = Project.find_by_identifier('test_project')
# project.add_member(user)


# -- make user a project administrator  

# user = User.find_by_login('chester')
# project = Project.find_by_identifier('test_project')
# project.add_admin(user)


# -- remove project admin privileges

# user = User.find_by_login('chester')
# project = Project.find_by_identifier('test_project')
# project.remove_admin(user)


# -- remove user from a project team

# user = User.find_by_login('chester')
# project = Project.find_by_identifier('test_project')
# project.remove_member(user)


# -- deactivate a user

# user = User.find_by_login('chester')
# user.update_attribute(:activated, false)


# -- re-activate a user

# user = User.find_by_login('chester')
# user.update_attribute(:activated, true)


