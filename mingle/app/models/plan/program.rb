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

require File.join(File.dirname(__FILE__), 'has_many_projects')
require File.join(File.dirname(__FILE__), 'accessibility')

class Program < Deliverable

  include Identifiable
  include Planner::HasManyProjects
  extend Accessibility

  has_one :cache_key_DO_NOT_REFERENCE, :class_name => 'CacheKey', :foreign_key => 'deliverable_id'

  has_many :objectives, :dependent => :destroy
  has_many :objective_types, :dependent => :destroy
  has_one :plan, :dependent => :destroy

  has_many :events, :order => 'mingle_timestamp, id ASC', :include => [:origin, :created_by, :changes ], :foreign_key => 'deliverable_id'
  has_many :events_without_eager_loading, :class_name => '::Event', :order => 'id ASC', :foreign_key => 'deliverable_id'

  has_many :dependency_views, :class_name => "ProgramDependencyView"
  named_scope :all_selected, lambda { |identifiers| {:conditions => ["identifier IN (?) ", identifiers]}  }


  validates_uniqueness_of :name, :case_sensitive => false
  validates_length_of :name, :maximum => 255

  after_create :initialize_plan!, :create_objective_number_sequence, :add_current_user_as_team_member, :create_default_objective_type, :add_default_objective_property_definitions

  before_destroy :clean_memberships

  def add_current_user_as_team_member
    add_member(User.current, :program_admin)
  end

  strip_on_write

  def create_default_objective_type
    objective_types.create(ObjectiveType.default_attributes)
  end

  def rename_along_with_identifier(new_name)
    new_name = MingleUpgradeHelper.fix_string_encoding_19(new_name) if MingleUpgradeHelper.ruby_1_9?
    self.name = new_name
    proposed_identifier = new_name.downcase.gsub(/[^a-z0-9]/, '_')
    self.identifier = Program.unique(:identifier, proposed_identifier)
  end

  def to_param
    identifier
  end

  def team_member_is_removable?
    true
  end

  def cache_key
    cache_key_DO_NOT_REFERENCE if cache_key_DO_NOT_REFERENCE
    key = CacheKey.create(:deliverable_id => self.id, :deliverable_type => "Program")
    self.cache_key_DO_NOT_REFERENCE = key
  end

  def feed_title
    "Mingle Plan Events for Program: #{name}"
  end

  def next_objective_number
    Sequence.find_table_sequence(objective_number_sequence_name).next
  end

  def reset_objective_number_sequence
    Sequence.find_table_sequence(objective_number_sequence_name).reset_to(highest_objective_number)
  end

  def normalize_positions
    backlog_objectives = objectives.backlog
    max = backlog_objectives.maximum(:position)
    unless (1..max).to_a == backlog_objectives.map(&:position)
      backlog_objectives.each_with_index do |obj, index|
        obj.update_attribute(:position, index + 1)
      end
    end
  end

  def reorder_objectives(new_order)
    position = 1
    new_order.each do |objective_id|
      objectives.backlog.find(objective_id).update_attribute :position, position
      position += 1
    end
  end

  def default_objective_type
    objective_types.default.first
  end

  private

  def add_default_objective_property_definitions
    return unless connection.table_exists?('objective_prop_defs') || connection.table_exists?('obj_prop_defs')
    objective_prop_table  =  connection.table_exists?('objective_prop_defs') ? 'objective_prop_defs' : 'obj_prop_defs'
    objective_prop_mapping_table =  connection.table_exists?('objective_prop_mappings')  ? 'objective_prop_mappings' : 'obj_prop_mappings'
    program_id = self.id
    connection.execute SqlHelper.sanitize_sql("INSERT INTO #{t(objective_prop_table)} (id, name, program_id, type, created_at, updated_at)
                                VALUES (#{connection.next_id_sql(objective_prop_table)} ,?, ?, ?, ?, ?)",
                         'Size', program_id, 'ManagedNumber', Clock.now, Clock.now)
    connection.execute SqlHelper.sanitize_sql("INSERT INTO #{t(objective_prop_table)} (id, name, program_id, type, created_at, updated_at)
                                VALUES (#{connection.next_id_sql(objective_prop_table)} ,?, ?, ?, ?, ?)",
                         'Value', program_id, 'ManagedNumber', Clock.now, Clock.now)

    size_id = connection.execute(SqlHelper.sanitize_sql("SELECT id FROM #{t(objective_prop_table)} WHERE name = 'Size' AND #{c('program_id')} = ?", program_id)).first['id']
    value_id = connection.execute(SqlHelper.sanitize_sql("SELECT id FROM #{t(objective_prop_table)} WHERE name = 'Value' AND #{c('program_id')} = ?", program_id)).first['id']
    objective_type_id = connection.execute(SqlHelper.sanitize_sql("SELECT id FROM #{t('objective_types')} WHERE name = 'Objective' AND #{c('program_id')} = ?", program_id)).first['id']

    connection.execute SqlHelper.sanitize_sql("INSERT INTO #{t(objective_prop_mapping_table)} (id, #{c(objective_prop_table.gsub(/s\b/, '_id'))}, objective_type_id)
                                VALUES (#{connection.next_id_sql(objective_prop_mapping_table)}, ?, ?)", size_id, objective_type_id)

    connection.execute SqlHelper.sanitize_sql("INSERT INTO #{t(objective_prop_mapping_table)} (id, #{c(objective_prop_table.gsub(/s\b/, '_id'))}, objective_type_id)
                                VALUES (#{connection.next_id_sql(objective_prop_mapping_table)}, ?, ?)", value_id, objective_type_id)

    add_objective_property_definitions_values if connection.table_exists?('obj_prop_values')
  end

  def highest_objective_number
    objectives.maximum('number')
  end

  def initialize_plan!
    @plan = Plan.create! :program => self
  end

  def touch_structure_key

  end

  def create_objective_number_sequence
    TableSequence.create(:name => objective_number_sequence_name)
  end

  # def create_backlog_objective_number_sequence
  #   TableSequence.create(:name => objective_backlog_number_sequence)
  # end

  def objective_number_sequence_name
    "program_#{id}_objective_numbers"
  end

  def t(table_name)
    connection.safe_table_name(table_name)
  end

  def c(column_name)
    connection.quote_column_name(column_name)
  end

  def add_objective_property_definitions_values
    obj_prop_def_ids = connection.execute SqlHelper.sanitize_sql("SELECT #{c('id')} FROM #{t('obj_prop_defs')} WHERE #{c('program_id')} = ?",self.id)
    obj_prop_def_ids.each do |obj_prop_def_id_hash|
      obj_prop_def_id = obj_prop_def_id_hash['id']
      11.times do |value|
        value = value * 10
        connection.execute SqlHelper.sanitize_sql(
                    "INSERT INTO #{t('obj_prop_values')} (id, obj_prop_def_id, value, created_at, updated_at)
                            VALUES (#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}obj_prop_values")} ,?, ?, ?, ?)",
                    obj_prop_def_id, value, Clock.now, Clock.now
                )
      end

    end
  end
end
