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

class Deliverable
  module ClearHasManyMemberCache
    def reload(*args)
      clear_cached_results_for(:admins)
      clear_cached_results_for(:role_for)
      super(*args)
    end
  end
  module ClassMethods
    def group_users_by_deliverable
      query = UserMembership
                  .joins(:group)
                  .where("user_memberships.group_id = groups.id AND groups.internal = ? and deliverable_id in (select id from deliverables where type = '#{self}')", true)
                  .group(:user_id, :deliverable_id).select(:user_id, :deliverable_id).to_sql
      result = ApplicationRecord.connection.select_all(query)
      result.to_hash.reduce({}) {|res, values| res[values['deliverable_id']] ||= []; res[values['deliverable_id']] << values['user_id']; res}
    end
  end
  module HasManyMembers
    def self.included(base)
     base.has_many :member_roles, :extend => MemberRole::AssociationExt
      base.has_many :groups
      base.has_one  :team, -> { where internal: true }, :class_name => 'Group'
      base.has_many :user_defined_groups, -> { where internal: false }, :class_name => 'Group'
      base.after_create do |record|
        record.groups.create(:name => 'Team', :internal => true) # todo: move it to project.create_team
      end
     base.send(:prepend, ClearHasManyMemberCache)
     base.send(:extend, ClassMethods)
    end

    def auto_enroll_enabled?
      false
    end

    def users
      if auto_enroll_enabled?
        User.all
      else
        self.team.users
      end
    end

    def member?(user)
      return false if user.nil?
      if auto_enroll_enabled?
        User.exists?(user.id)
      else
        self.team.member?(user)
      end
    end

    # methods to member_roles
    def readonly_member?(user)
      role_for(user) == MembershipRole[:readonly_member]
    end

    def full_member?(user)
      role_for(user) == MembershipRole[:full_member]
    end

    def project_admin?(user)
      self.member_roles.project_admin?(user)
    end

    def admin?(user)
      self.member_roles.admin?(user)
    end

    def role_for(member)
      ret = MemberRole.user_deliverable_roles(member, self).first.try(:role)
      if !ret && auto_enroll_enabled?
        return MembershipRole[:readonly_member] if member.light?
        return MembershipRole[:readonly_member] if all_users_are_read_only_members?
        return MembershipRole[:full_member]
      end
      ret
    end
    memoize :role_for
    # methods to member_roles end

    # moved from Group class
    def version_control_users
      users.inject({}) do |result, user|
        result[user.version_control_user_name] = user if user.version_control_user_name
        result
      end
    end

    def add_member(user, role=default_role)
      team.add_member(user)
      member_roles.setup_user_role(user, role)
      reload
    end

    def change_members_role(members_ides, role=default_role)
      member_roles.where(member_id: members_ides).update_all( permission: MembershipRole[role].id)
    end

    def clean_memberships
      ::MemberRole.delete_all(:deliverable_id => self.id)

      ::UserMembership.delete_all(["group_id IN (SELECT id from #{Group.table_name} where deliverable_id = ?)", self.id])
      ::Group.delete_all(:deliverable_id => self.id)
    end

    def reload_with_clear_has_many_member_cache(*args)
      clear_cached_results_for(:admins)
      clear_cached_results_for(:role_for)
      reload_without_clear_has_many_member_cache(*args)
    end

    def groups_for_member(member)
      user_defined_groups.select {|g| g.member?(member)}
    end

    def admins
      users.scoped(:conditions => "#{User.quoted_table_name}.id IN ( #{member_roles.project_admin_ids_sql} )")
    end
    memoize :admins

    def change_member_to_readonly_for_light_users
      users.select(&:light?).each{|user| add_member(user, :readonly_member) }
    end

    def remove_member(user)
      ::ProjectMemberDeletion.for_direct_member(self, user).execute.tap { reload }
    end

    def mingle_admin_or_member_but_not_readonly?(user)
      user.admin? || (member?(user) && !readonly_member?(user))
    end
  end
end
