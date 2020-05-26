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

module AutoEnrollUserType

  ALL_USERS_ARE_READ_ONLY_MEMBERS = 'readonly'
  ALL_USERS_ARE_FULL_MEMBERS = 'full'

  module ProjectExt
    def self.included(base)
      base.after_update :all_users_become_members_if_required
      base.validate :validate_auto_enroll_user_type
      base.named_scope :auto_enroll_enabled, :conditions => ['auto_enroll_user_type IS NOT NULL AND hidden = ?', false]
      class << base
        def reset_auto_erolled_projects
          Project.all.map(&:disable_auto_enroll)
        end
      end
    end

    def disable_auto_enroll
      with_active_project do
        if auto_enroll_enabled?
          update_attributes(:auto_enroll_user_type => nil)
        end
      end
    end

    def all_users_become_members_if_required
      if changed.include?('auto_enroll_user_type') && !self.auto_enroll_enabled?
        auto_enroll_missing_users
      end
    end

    def team_member_is_removable?
      auto_enroll_user_type.blank?
    end

    def auto_enroll_enabled?
      !auto_enroll_user_type.blank?
    end

    def all_users_are_read_only_members?
      ALL_USERS_ARE_READ_ONLY_MEMBERS == auto_enroll_user_type
    end

    def all_users_are_full_members?
      ALL_USERS_ARE_FULL_MEMBERS == auto_enroll_user_type
    end

    def validate_auto_enroll_user_type
      return unless auto_enroll_enabled?
      return if all_users_are_full_members? || all_users_are_read_only_members?

      errors.add_to_base "#{auto_enroll_user_type.inspect} is not a valid value for \"auto_enroll_user_type\", which is restricted to #{ALL_USERS_ARE_FULL_MEMBERS.inspect}, #{ALL_USERS_ARE_READ_ONLY_MEMBERS.inspect}, or nil"
    end

    def autoenroll_role_for(user)
      role_for_enroll(user)
    end

    private

    def auto_enroll_missing_users
      auto_enroll_users(User.find(:all, :conditions => ["id NOT IN (#{UserMembership.user_ids_sql(:conditions => {:group_id => team.id})})"]))
    end

    def auto_enroll_users(users)
      team.add_nonmembers_in(users)

      users.group_by(&method(:role_for_enroll)).each do |role, role_users|
        data = role_users.map do |user|
          {'permission' => role.id_db_string, 'member_id' => user.id, 'member_type' => User.name, 'deliverable_id' => self.id}
        end
        Project.connection.bulk_insert(MemberRole, data)
      end
      CacheKey.touch(:structure_key, self)
    end

    def role_for_enroll(user)
      role_name = if user.light?
                    :readonly_member
                  else
                    all_users_are_read_only_members? ? :readonly_member : :full_member
                  end
      MembershipRole[role_name]
    end
  end
end
