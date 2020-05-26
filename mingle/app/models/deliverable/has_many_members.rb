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
  module HasManyMembers
    def self.included(base)
      base.has_many :member_roles, :extend => MemberRole::AssociationExt
      base.has_many :groups
      base.has_one  :team, :class_name => 'Group', :conditions => {:internal => true}
      base.has_many :user_defined_groups, :class_name => 'Group', :conditions => {:internal => false}

      base.after_create do |record|
        record.groups.create(:name => 'Team', :internal => true) # todo: move it to project.create_team
      end
      base.alias_method_chain :reload, :clear_has_many_member_cache
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

    def add_member(user, role=nil)
      team.add_member(user)
      member_roles.setup_user_role(user, role)
      reload
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

    def team_members_with_role_and_group_info(batch_size = 999)
      user_name = "#{connection.quote_column_name('users.name')} AS \"Name\""
      user_login = "#{connection.quote_column_name('users.login')} AS \"Sign-in name\""
      user_email = "#{connection.quote_column_name('users.email')} AS \"Email\""
      user_permission = "#{connection.quote_column_name('member_roles.permission')} AS \"Permissions\""
      user_groups = ""
      if connection.database_vendor == :oracle
        user_groups = "listagg(#{connection.quote_column_name('groups.name')} ,', ') WITHIN GROUP (ORDER BY LOWER(#{connection.quote_column_name('groups.name')}) ASC ) AS \"User groups\""
      else
        user_groups = "string_agg(#{connection.quote_column_name('groups.name')} , ', ' ORDER BY LOWER(#{connection.quote_column_name('groups.name')}) ASC ) AS \"User groups\""
      end
      sql = SqlHelper.sanitize_sql(
          "SELECT  #{connection.quote_column_name('users.id')}, #{user_name}, #{user_login}, #{user_email}, #{user_permission}, #{user_groups}  FROM #{connection.quote_table_name('users')}
                  INNER JOIN #{connection.quote_table_name('user_memberships')}
                        ON #{connection.quote_column_name('user_memberships.user_id')} = #{connection.quote_column_name('users.id')}
                  INNER JOIN #{connection.quote_table_name('groups')}
                        ON #{connection.quote_column_name('groups.deliverable_id')} = ?
                           AND #{connection.quote_column_name('groups.id')} = #{connection.quote_column_name('user_memberships.group_id')}
                  INNER JOIN #{connection.quote_table_name('member_roles')}
                        ON #{connection.quote_column_name('member_roles.member_id')} = #{connection.quote_column_name('users.id')}
                           AND #{connection.quote_column_name('member_roles.deliverable_id')} = ?
                  WHERE #{connection.quote_column_name('users.system')} != ?
                  GROUP BY #{connection.quote_column_name('users.id')},
                           #{connection.quote_column_name('users.name')},
                           #{connection.quote_column_name('users.login')},
                           #{connection.quote_column_name('users.email')},
                           #{connection.quote_column_name('member_roles.permission')}
                  ORDER BY #{connection.quote_column_name('users.name')} ASC",
          self.id, self.id, connection.true_value
      )
      members = connection.execute sql
      if auto_enroll_enabled?
        existing_team_member_ids = connection.execute(SqlHelper.sanitize_sql(
            "SELECT #{connection.quote_column_name('user_memberships.user_id')} FROM #{connection.quote_table_name('user_memberships')}
             INNER JOIN #{connection.quote_table_name('groups')} ON #{connection.quote_column_name('groups.id')} = #{connection.quote_column_name('user_memberships.group_id')}
             AND #{connection.quote_column_name('groups.deliverable_id')} = ?", self.id))
        last_user_id = 0
        existing_team_member_ids.each_slice(batch_size) do |team_members|
          team_members = team_members.map { | member|  member['user_id'] }
          sql = SqlHelper.sanitize_sql(
              "SELECT #{connection.quote_column_name('users.id')}, #{user_name}, #{user_login}, #{user_email},  '#{self.auto_enroll_user_type.downcase == 'full' ? 'full_member' : 'readonly_member' }' AS \"Permissions\", 'Team' AS \"User groups\" FROM #{connection.quote_table_name('users')}
                    WHERE #{connection.quote_column_name('users.id')} > #{last_user_id}
                      AND #{connection.quote_column_name('users.system')} != ?
                      AND #{connection.quote_column_name('users.id')} NOT IN (?)
                 ORDER BY #{connection.quote_column_name('users.id')} ASC",
              connection.true_value, team_members
          )

          sql_out = connection.execute(sql)
          last_user_id = sql_out.last.try(:[], 'id')
          members = members.concat(sql_out)
          break if last_user_id.nil?
        end
      end
      members.uniq
    end
  end
end
