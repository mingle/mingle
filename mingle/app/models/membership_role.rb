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

class MembershipRole
  attr_reader :name, :id, :privilege_level
  
  include Comparable
  
  def initialize(name, id, privilege_level)
    @name = name
    @id = id
    @privilege_level = privilege_level
  end

  PROJECT_ROLES = ([
      MembershipRole.new('Team member', :full_member, UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER),
      MembershipRole.new('Read only team member', :readonly_member, UserAccess::PrivilegeLevel::READONLY_TEAM_MEMBER),
      MembershipRole.new('Project administrator', :project_admin, UserAccess::PrivilegeLevel::PROJECT_ADMIN),
  ]).freeze

  PROGRAM_ROLES = ([
      MembershipRole.new('Program administrator', :program_admin, UserAccess::PrivilegeLevel::PROJECT_ADMIN),
      MembershipRole.new('Program member', :program_member, UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER)
  ]).freeze

  ALL_ROLES = (PROJECT_ROLES + PROGRAM_ROLES).freeze

  class << self
    def all(deliverable_type=nil)
      return MembershipRole.const_get("#{deliverable_type.upcase}_ROLES")unless deliverable_type.nil?
      ALL_ROLES
    end
    
    def [](id)
      id ||= default
      ALL_ROLES.detect { |r| r.to_sym == id.to_sym } || raise("Cannot find role matching '#{id}'.")
    end

    def exist?(role)
      return true if role.nil?
      ALL_ROLES.any?{|r| r.to_sym == role.to_sym}
    end

    def default
      self[:full_member]
    end
  end
  
  def to_s
    @name
  end
  
  def to_sym
    @id
  end
  
  def name_id_pair
    [name, id]
  end
  
  def <=>(another)
    @privilege_level <=> another.privilege_level
  end

  def id_db_string
    id.to_s
  end
end
