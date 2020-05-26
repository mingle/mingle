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

class UserMembership < ApplicationRecord
  belongs_to :user
  belongs_to :group
  before_destroy :validate_removal_from_team

  validates_uniqueness_of :user_id, :scope => [:group_id]

  class << self
    def user_ids_sql(options={})
      self.send(:construct_finder_sql, options.merge(:select => :user_id))
    end
  end

  def deliverable
    ThreadLocalCache.get_assn(self, :group, :deliverable)
  end

  def deliverable_id
    deliverable.id
  end

  def validate_removal_from_team
    group.user_defined? ? true : begin
      errors.add_to_base "Cannot remove #{user.name.bold} from team, because project is enabled enroll all users as team members." unless deliverable.team_member_is_removable?
      errors.add_to_base "Cannot remove yourself from team." if (!user.admin?) && user == User.current && deliverable.project_admin?(user)
      errors.empty?
    end
  end
end
