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

module ProgramMembershipsHelper
  include UsersHelper
  
  def add_column(user)
    case
    when @program.member?(user)
      'Existing team member'
    when user.light?
      "Light user cannot be added as program team member"
    else
      link_to_remote('Add to team', {:url => { :action => 'create', :user_id => user.id, :program_id => @program.to_param }, :before => "$('#{user.html_id}_spinner').show()"}, :class => 'actionable')
    end
  end
end
