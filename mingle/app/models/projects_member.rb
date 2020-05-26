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

# Only use this for legacy api!!!
class ProjectsMember  
  include API::XMLSerializer
  
  v1_serializes_as :complete => [:admin, :id, :project_id, :readonly_member, :user_id, :user],
                   :compact => [:user]
  v2_serializes_as :complete => [:id, :admin, :readonly_member, :user, :project],
                   :compact => [:user]
  compact_at_level 2
  
  attr_reader :project, :user
  
  def initialize(project, user)
    @project, @user = project, user
  end
  
  def id
    "proj#{project.id}_#{user.id}"
  end
  
  def admin
    project.project_admin?(user)
  end  

  def readonly_member
    project.readonly_member?(user)
  end
  
  def user_id
    user.id
  end
  
  def project_id
    project.id
  end
end
