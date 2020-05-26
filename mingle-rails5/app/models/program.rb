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

class Program < Deliverable
  include Identifiable
  auto_strip_attributes :name, squish: true, nullify: false
  has_one :plan, :dependent => :destroy
  has_many :objectives, -> {order :position}, :dependent => :destroy
  has_many :objective_types, :dependent => :destroy
  has_many :program_projects, :dependent => :destroy
  has_many :projects, :through => :program_projects
  has_many :objective_property_definitions, :dependent => :destroy

  validates_uniqueness_of :name, :case_sensitive => false
  validates_length_of :name, :maximum => 255

  after_create :initialize_plan!, :create_objective_number_sequence, :create_default_objective_type, :add_current_user_as_team_member, :add_default_objective_property_definitions

  # before_destroy :clean_memberships

  def next_backlog_objective_number
    Sequence.find_table_sequence(objective_backlog_number_sequence).next
  end

  def next_objective_number
    Sequence.find_table_sequence(objective_number_sequence_name).next
  end

  def last_backlog_objective_number
    Sequence.find_table_sequence(objective_number_sequence_name).current
  end

  def reorder_objectives(new_order)
    position = 1
    new_order.each do |number|
      objective = objectives.find_by_number(number)
      objective.update_attribute :position, position
      position += 1
    end
  end

  def default_role
    :program_member
  end

  def projects_associated
    projects.map{|project| project.name}
  end

  def members_for_login(members_login)
    members.where(member_id: [User.all.where(login:members_login).map(&:id)])
  end

  def members
    member_roles.includes(:member)
  end

  def default_objective_type
    objective_types.default.first
  end

  private

  def initialize_plan!
    @plan = Plan.create! :program => self
  end

  def create_objective_number_sequence
    TableSequence.create(:name => objective_number_sequence_name)
  end

  def create_default_objective_type
    objective_types.create(ObjectiveType.default_attributes)
  end

  def add_current_user_as_team_member
    add_member(User.current, :program_admin) unless User.current.anonymous?
  end

  def add_default_objective_property_definitions
    default_properties = ObjectivePropertyDefinition.create_default_properties(self.id)
    objective_type = ObjectiveType.where("program_id = ? AND name = ?", self.id, 'Objective').first
    ObjectivePropertyMapping.create_property_mappings(default_properties, objective_type)
  end

  def objective_number_sequence_name
    "program_#{id}_objective_numbers"
  end
end
