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

class Objective < ApplicationRecord
  include Identifiable

  module Status
    PLANNED = 'PLANNED'
    BACKLOG = 'BACKLOG'
  end
  include Status

  auto_strip_attributes :name, squish: true, nullify: false
  ALLOWED_CHARACTERS_IN_IDENTIFIER = /[^a-zA-Z0-9]/
  self.primary_key = 'id'
  belongs_to :program
  belongs_to :objective_type
  belongs_to :modified_by, :class_name => '::User', :foreign_key => 'modified_by_user_id'
  has_many :objective_property_value_mappings, dependent: :destroy
  has_many :objective_property_definitions, through: :objective_type

  acts_as_versioned_ext :keep_versions_on_destroy => true
  scope :backlog, -> {where(status: BACKLOG).order(:position)}
  scope :planned, -> {where(status: PLANNED)}
  scope :all_objectives, -> {order(:position).order(:status)}
  scope :after, ->(obj) { where('position > ?', obj.position) }

  scope :in_current_month, -> (beginning_of_current_month = Clock.now.beginning_of_month.to_s(:db),
  end_of_current_month = Clock.now.end_of_month.to_s(:db), start_at = Objective.arel_table[:start_at], end_at = Objective.arel_table[:end_at] ) { Objective.where( start_at.gteq(beginning_of_current_month)).where(start_at.lteq(end_of_current_month)).or(Objective.where( end_at.gteq(beginning_of_current_month)).where(end_at.lteq(end_of_current_month))).or(Objective.where( start_at.lt(beginning_of_current_month)).where(end_at.gt(end_of_current_month)))
  }

  scope :newly_planned_objectives, ->  { where ("vertical_position = 6 and status = 'PLANNED'")}

  after_create :default_to_top_position
  after_destroy :create_objective_deletion_version
  after_destroy :update_positions
  before_save :sanitize_value_statement
  after_find :format_text

  validates_presence_of :program
  validates_presence_of :objective_type
  validates_uniqueness_of :name, :scope => :program_id, :case_sensitive => false, message: 'already used for an existing Objective in your Program.', length: {maximum: 80}
  validates_presence_of :start_at, :if => Proc.new {|obj| obj.status == PLANNED}
  validates_presence_of :end_at, :if => Proc.new {|obj| obj.status == PLANNED}
  validate :end_at_date_should_be_after_start_at_date, :if => Proc.new {|obj| obj.start_at && obj.end_at}
  validates_length_of :name, :maximum => 80

  before_create :assign_number
  before_validation :set_default_objective_type

  before_save :set_modified_by_user, :if => Proc.new {|obj| obj.status == PLANNED}
  after_save :resize_plan_to_accomodate_objective, :if => Proc.new {|obj| obj.status == PLANNED}
  before_validation :generate_identifier, if: Proc.new { |objective| objective.new_record? || objective.name_changed? }

  def set_default_objective_type
    unless self.objective_type_id
      self.objective_type = program.default_objective_type
    end
  end

  def unique(identifier, candidate)
    return candidate if self.program.nil?
    Objective.unique(identifier, candidate, '', {:program_id => self.program.id})
  end

  def plan
    self.status = PLANNED
    save!
  end

  def update_attributes(attributes_value_hash)
    updated = super(attributes_value_hash.except(:property_definitions))
    update_objective_property_value_mappings(attributes_value_hash[:property_definitions])
    updated
  end

  def to_params(include_property_definitions=true)
    attrs = self.attributes.symbolize_keys.slice(:name, :number, :position, :status, :value_statement)
    attrs = attrs.merge(property_definitions: property_definitions) if include_property_definitions
    attrs
  end

  def create_property_value_mappings(property_definitions)
    return if property_definitions.nil?
    self.objective_property_definitions.where(name:property_definitions.keys).each do |obj_prop_def|
      obj_prop_value = obj_prop_def.objective_property_values.find_by_value(property_definitions[obj_prop_def.name.to_sym][:value])
      objective_property_value_mappings.create(obj_prop_value_id: obj_prop_value.id) unless obj_prop_value.nil?
    end
  end

  private

  def property_definitions
    self.objective_property_definitions.reduce({}) do | obj_prop_defs, obj_prop_def|
      obj_prop_value_mapping = property_value_mapping(obj_prop_def)
      obj_prop_defs[obj_prop_def.name.to_sym] = {
          name: obj_prop_def.name,
          value: obj_prop_value_mapping.value,
          allowed_values:obj_prop_def.allowed_values
      } unless obj_prop_value_mapping.nil?
      obj_prop_defs
    end
  end

  def assign_number
    self.number = program.next_objective_number
  end

  def set_modified_by_user
    self.modified_by = User.current
  end

  def generate_identifier
    candidate = name.gsub(ALLOWED_CHARACTERS_IN_IDENTIFIER, '_').downcase
    if candidate =~ /^\d.*/
      candidate = 'objective_' + candidate
    end
    self.identifier = self.unique(:identifier, candidate)
  end

  def end_at_date_should_be_after_start_at_date
    errors.add(:end_at, 'should be after start date') if self.start_at > self.end_at
  end

  def resize_plan_to_accomodate_objective
    attributes_to_update = {}
    attributes_to_update.merge! :start_at => start_at if program.plan.start_at > start_at
    attributes_to_update.merge! :end_at => end_at if program.plan.end_at < end_at

    program.plan.update_attributes(attributes_to_update) if attributes_to_update.any?
  end

  def default_to_top_position
    all = self.status.match(BACKLOG) ? program.objectives.backlog : program.objectives.planned
    update_attribute(:position, 1)
    others = all - [self]
    others.each_with_index do |objective, index|
      objective.update_attribute(:position, index + 2)
    end
  end

  def update_positions
    all = self.status.match(BACKLOG) ? program.objectives.backlog : program.objectives.planned
    all.after(self).each do |objective|
      objective.update_attribute(:position, objective.position.pred)
    end
  end

  def sanitize_value_statement
    self.value_statement = HtmlSanitizer.new.sanitize value_statement
  end

  def format_text
    return self unless self.respond_to?(:value_statement)
    return self if self.value_statement.blank?
    if Nokogiri.parse(self.value_statement).text.blank?
      self.value_statement = self.value_statement.split("\n").map do |line|
        line = line.gsub(/\s+/) do |white_spaces|
          white_spaces = "&nbsp;" * white_spaces.length if white_spaces.length > 1
          white_spaces
        end
        "<p>#{line}</p>"
      end.join("</br>")
    end
    self
  end

  def update_objective_property_value_mappings(new_prop_values)
    return if new_prop_values.nil?
    self.objective_property_definitions.where(name: new_prop_values.keys).each do |obj_prop_def|
      value_mapping = property_value_mapping(obj_prop_def)
      obj_prop_value = obj_prop_def.objective_property_values.find_by_value(new_prop_values[obj_prop_def.name.to_sym][:value])
      create_or_update_property_value_mapping(obj_prop_value, value_mapping)
    end
  end

  def create_or_update_property_value_mapping(obj_prop_value, value_mapping)
    return if obj_prop_value.nil?
    if value_mapping.is_a?(NullPropertyValueMapping)
      objective_property_value_mappings.create(obj_prop_value_id:obj_prop_value.id)
    else
      value_mapping.update_attribute(:obj_prop_value_id, obj_prop_value.id)
    end
  end

  def property_value_mapping(obj_prop_def)
    objective_property_value_mappings.where(obj_prop_value_id: obj_prop_def.objective_property_values.select(:id)).take || NullPropertyValueMapping.new
  end

  def create_objective_deletion_version
    version_attributes = {version: next_version,
                          vertical_position: vertical_position,
                          identifier: identifier,
                          value_statement: value_statement,
                          size: size,
                          value: value,
                          name: name,
                          start_at: start_at,
                          end_at: end_at,
                          modified_by_user_id: User.current.id,
                          number: number,
                          status: status,
                          program_id: program.id,
                          objective_id: id,
                          objective_type_id: objective_type_id}

    Objective::Version.create!(version_attributes)
  end

end

class Objective::Version < ApplicationRecord
  after_create :fire_create_event

  belongs_to :modified_by, class_name: ::User, foreign_key: :modified_by_user_id
  belongs_to :program
  belongs_to :objective_type
  has_one :event, as: :origin, class_name: ::Event

  validates_presence_of :objective_type

  def t(table_name)
    ActiveRecord::Base.connection.safe_table_name(table_name)
  end

  def c(column_name)
    ActiveRecord::Base.connection.quote_column_name(column_name)
  end

  def first_version
    self.class.minimum(:version, :conditions => ['objective_id = ?', self.objective_id])
  end

  def first?
    version == first_version
  end

  def previous
    (self.version - 1).downto(1) do |version|
      previous = self.class.find(:first, :conditions => ["objective_id = ? AND version = ?", self.objective_id, version])
      return previous unless previous.nil?
    end
    nil
  end

  def objective_resource_link
    Objective.resource_link("Feature: #{name}", {:id => identifier, :program_id => program.identifier })
  end

  private

  def fire_create_event
    user_id = modified_by.nil? ? nil : modified_by.id
    Event.with_program_scope(program_id, updated_at, user_id) do |options|
      if Objective.find_by_identifier_and_program_id(identifier, program_id).present?
        Event.objective_version(self, options)
      else
        Event.objective_deletion(self, options)
      end
    end
  end
end
