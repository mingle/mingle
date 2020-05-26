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
#  This script creates a new Mingle project. 
#
#  Edit the project_attributes hash starting on line 18 to
#  specify the project's basic configuration.
# 
#  To execute this script, from the installation directory, run:
#  $ tools/run tools/create_project.rb
#  
# ----------

begin
  User.first_admin
rescue 
  raise "The script requires that Mingle already be configured and have at least 1 user with full admin privileges."
end

# description, repository_path, card_keywords, email_address, email_sender_name are optional
project_attributes = {
  :name => 'My New Project',
  :identifier => 'my_new_project',
  :description => 'cool beans!',
  :repository_path => '/Users/david/repos',
  :card_keywords => 'card, #, bug, defect, story',
  # :email_address => 'i_send_history_emails@this.project',
  # :email_sender_name => 'i send history emails'
}

User.with_first_admin do
  Project.create!(project_attributes)
end
