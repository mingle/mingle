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

class Group < ApplicationRecord
  auto_strip_attributes :name, nullify: false

  belongs_to :deliverable
  has_many :user_memberships, dependent: :destroy
  has_many :users, :through => :user_memberships

  # TODO IMPORTANT need to uncomment this section
  # has_many :transition_prerequisites, :dependent => :delete_all
  validates :name, presence: true, length: { maximum: 255 }, uniqueness: {scope: :deliverable_id, case_sensitive: false}
  validates_format_of :name, :message => 'cannot contain comma.', :with => /\A[^,]+\z/, if: ->(group) { group.name.length > 0 }, multiline: true

  scope :team, -> { where internal: true }

  scope :user_defined, -> { where internal: false }

  # TODO IMPORTANT need to uncomment this section
  # v2_serializes_as :complete => [:id, :name, :projects_members],
  #                  :compact => [:name]
  #
  # compact_at_level 0

  def remove_member(member)
    errors = validate_for_removal(member)
    raise errors.join("\n") if errors.any?
    users.delete(member).tap do
      um = UserMembership.new(:group_id => self.id, :user_id => member.id)
      # TODO IMPORTANT need to find an alternative to observer
      # UserMembership.notify_observers(:after_destroy, um)
    end
  end

  def remove_members_in(members)
    members.map {|member| remove_member(member)}
  end

  def add_member(user)
    return if member?(user)
    users << user
  end

  def add_members_in(users_to_add)
    add_nonmembers_in(users_to_add - self.users)
  end

  def add_nonmembers_in(nonmembers)
    return if nonmembers.empty?
    data = nonmembers.map {|user| {'group_id' => self.id, 'user_id' => user.id}}
    self.class.connection.bulk_insert(UserMembership, data)
    users.reload
  end

  def member?(user)
    return false if !user || user.anonymous?
    users.any? {|one_user| one_user.id == user.id }
  end

  def all_are_members?(users)
    (users - self.users).empty?
  end

  def any_is_member?(users)
    (users - self.users).size < users.size
  end

  def unused?
    user_memberships.count == 0 && transition_prerequisites.count == 0
  end

  def user_defined?
    !internal?
  end

  # todo: this is a leaking for team abstraction
  def validate_for_removal(member)
    [].tap do |errors|
      return errors if user_defined?
      # errors << "Cannot remove #{member.name.bold} from team, because project is enabled enroll all users as team members." unless deliverable.team_member_is_removable?
      errors << "Cannot remove yourself from team." if (!member.admin?) && member == User.current && deliverable.project_admin?(member)
    end
  end

  private
  # only for keep the old api, don't use!!!
  def projects_members
    users.collect { |user| ProjectsMember.new(deliverable, user) }
  end
end
