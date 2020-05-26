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

class MemberRole < ActiveRecord::Base
  belongs_to :deliverable
  belongs_to :member, :polymorphic => true
  composed_of :role, :class_name  => 'MembershipRole',
                     :mapping     => %w(permission id_db_string),
                     :constructor => Proc.new { |permission| MembershipRole[permission.to_sym] },
                     :converter   => Proc.new { |permission| MembershipRole[permission.to_sym] }
  named_scope :user_deliverable_roles, lambda {|user, deliverable| {:conditions => {:member_id => user.id, :member_type => user.class.name, :deliverable_id => deliverable.id}}}
  named_scope :all_project_admins, lambda { {conditions: {permission: 'project_admin'}} }
  module AssociationExt
    def for_members(members)
      members.collect { |m| find_by_member(m) }.compact
    end

    def membership_role(member)
      find_by_member(member).try(:role)
    end

    def setup_user_role(user, role_name)
      role_name ||= user.light? ? :readonly_member : :full_member
      role = MembershipRole[role_name]
      setup_role_for_member(user, role) if membership_role(user) != role
    end

    def destroy_for_member(member)
      if role = find_by_member(member)
        role.destroy.tap { reload }
      end
    end

    def destroy_for_members(members)
      for_members(members).map(&:destroy).tap { reload  }
    end

    def readonly_member?(user)
      membership_role(user) == MembershipRole[:readonly_member]
    end

    def project_admin?(user)
      membership_role(user) == MembershipRole[:project_admin]
    end

    def full_member?(user)
      membership_role(user) == MembershipRole[:full_member]
    end

    def admin?(user)
      user.admin? || project_admin?(user)
    end

    def find_by_member(member)
      if role = detect { |mr| member.class.name == mr.member_type && member.id == mr.member_id }
        role.member = member
        role
      end
    end

    private
    def setup_role_for_member(member, role)
      raise "#{member.name} cannot have role #{role}" if member.invalid_role?(role)
      member_role = find_by_member(member) || new(current_scoped_methods[:create].merge(:member => member))
      member_role.role = role
      member_role.save!
      self.reload
      member_role
    rescue => e
      Rails.logger.error("Error setting up role for member. error: #{e.inspect}")
      Rails.logger.error("  member id: #{member.id}, email: #{member.email}")
      Rails.logger.error("  auto_enroll_enabled => #{Project.current.auto_enroll_enabled?}")
      existing_member_role = find_by_member(member)
      Rails.logger.error("  existing role for member: #{existing_member_role.inspect}")
      Rails.logger.error("  Existing roles:")
      each { |existing_role| Rails.logger.error(existing_role.inspect) }
      raise
    end

  end

  def role_with_light_member_check
    return MembershipRole[:readonly_member] if member.light?
    role_without_light_member_check
  end

  def self.project_admin_ids_sql
    self.send(:sanitize_sql, [<<-SQL, 'project_admin'])
      SELECT member_id
      FROM member_roles
      WHERE #{current_scoped_methods[:find][:conditions]}
            AND member_roles.member_type = 'User'
            AND member_roles.permission = ?
    SQL
  end

  def self.admin_project_ids
    sql = self.send(:sanitize_sql, [<<-SQL, 'project_admin'])
      SELECT deliverable_id
      FROM member_roles
      WHERE #{current_scoped_methods[:find][:conditions]}
            AND member_roles.member_type = 'User'
            AND member_roles.permission = ?
    SQL
    connection.select_values(sql).map(&:to_i)
  end
  alias_method_chain :role, :light_member_check
end
