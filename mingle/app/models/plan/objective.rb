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

class Objective < ActiveRecord::Base
  include UrlIdentifierSupport
  include Messaging::Program::MessageProvider

  module Status
    PLANNED = 'PLANNED'
    BACKLOG = 'BACKLOG'
  end
  include Status

  ALLOWED_CHARACTERS_IN_IDENTIFIER = /[^a-zA-Z0-9]/
  IDENTIFIER_MAX_LENGTH = 30

  def self.not_set
    new(:name => "(not set)", :id => nil)
  end

  validates_uniqueness_of :identifier, :scope => :program_id

  include Identifiable

  belongs_to :program
  belongs_to :objective_type
  belongs_to :modified_by, :class_name => '::User', :foreign_key => 'modified_by_user_id'

  has_many :objective_snapshots, :order => 'id', :dependent => :destroy, :foreign_key => "objective_id"
  has_many :filters, :class_name => 'ObjectiveFilter', :dependent => :destroy

  attr_readonly :number

  acts_as_versioned_ext :association_options => {:include => [:modified_by]}, :keep_versions_on_destroy => true

  named_scope :started_before, lambda {|at| {:conditions => ['start_at < ? and status = ?', at, PLANNED]}}
  named_scope :order_by_number, lambda { { :order => "#{connection.quote_column_name('number')}"}}

  named_scope :in_current_month, lambda {
    beginning_of_current_month = Clock.now.beginning_of_month.to_s(:db)
    end_of_current_month = Clock.now.end_of_month.to_s(:db)
    {:conditions => ["((start_at >= #{connection.datetime_insert_sql(beginning_of_current_month)} and start_at <= #{connection.datetime_insert_sql(end_of_current_month)})
      or (end_at >= #{connection.datetime_insert_sql(beginning_of_current_month)} and end_at <= #{connection.datetime_insert_sql(end_of_current_month)})
      or (start_at < #{connection.datetime_insert_sql(beginning_of_current_month)} and end_at > #{connection.datetime_insert_sql(end_of_current_month)}))
      and status = ? ", PLANNED]}
  }

  named_scope :between_dates, lambda { |start_date, end_date|
    start_date = start_date.to_s(:db)
    end_date = end_date.to_s(:db)
    {:conditions => ["((start_at >= #{connection.datetime_insert_sql(start_date)} and start_at <= #{connection.datetime_insert_sql(end_date)})
      or (end_at >= #{connection.datetime_insert_sql(start_date)} and end_at <= #{connection.datetime_insert_sql(end_date)})
      or (start_at < #{connection.datetime_insert_sql(start_date)} and end_at > #{connection.datetime_insert_sql(end_date)}))
      and status = ?", PLANNED]}
  }

  named_scope :newly_planned_objectives, lambda { {:conditions => ["vertical_position = 6 and status = ?", PLANNED]} }
  named_scope :backlog, order: :position, conditions: {status: BACKLOG}
  named_scope :planned, order: :position, conditions: {status: PLANNED}
  named_scope :after, lambda { |objective| {:conditions => ["position > ?  and status = ?", objective.position, BACKLOG]} }

  validates_presence_of :program
  validates_presence_of :objective_type
  validates_uniqueness_of :name, :scope => :program_id, :case_sensitive => false,:message => "already used for an existing Feature."
  validates_presence_of :start_at, :if => Proc.new {|obj| obj.status == PLANNED}
  validates_presence_of :end_at, :if => Proc.new {|obj| obj.status == PLANNED}
  validate :end_at_date_should_be_after_start_at_date, :if => Proc.new {|obj| obj.start_at && obj.end_at}
  validates_length_of :name, :maximum => 80

  before_create :assign_number, :set_default_objective_type
  after_create :default_to_top_position, :create_objective_property_value_mappings

  before_destroy :delete_works, :if => Proc.new {|obj| obj.status == PLANNED}
  after_destroy :create_objective_deletion_version
  after_destroy :update_positions

  before_save :set_modified_by_user, :if => Proc.new {|obj| obj.status == PLANNED}
  after_save :resize_plan_to_accomodate_objective, :if => Proc.new {|obj| obj.status == PLANNED}
  before_validation :generate_identifier, :if => Proc.new { |objective| objective.new_record? || objective.name_changed? }
  before_validation :set_default_objective_type

  strip_on_write :except => [:value_statement]

  date_attributes :start_at, :end_at

  v2_serializes_as :complete => [:number, :identifier, :name, :start_at, :end_at, :status, [:works, {:element_name => 'work'}]],
                   :compact => [:number, :identifier, :name, :start_at, :end_at, :status]

  def set_default_objective_type
    unless self.objective_type_id
      self.objective_type = program.default_objective_type if self.program_id
    end
  end

  def self.required_parameters
    [:start_at, :end_at, :name]
  end

  def auto_sync?(project)
    ObjectiveFilter.exists?(:objective_id => self.id, :project_id => project.id)
  end

  def sync_finished?
    filters.all?(&:synced?)
  end

  def works
    program.plan.works.scheduled_in(self)
  end

  def full_name
    "#{plan.name}:#{self.name}"
  end

  def progress
    works = program.plan.works.scheduled_in(self)
    program.projects_with_work_in(self).inject({}) do |progress, project|
      total = works.created_from(project).count
      done = works.created_from(project).completed.count
      progress[project.identifier] = {:done => done, :total => total, :name  => project.name.escape_html} if total > 0
      progress
    end
  end

  def projections
    program.projects_with_work_in(self).inject({}) do |projections, project|
      projections[project.identifier] = forecast.for(project)
      projections
    end
  end

  def projects
    program.projects_with_work_in(self)
  end

  def forecast
    Plan::Forecast.new(self)
  end

  def late?
    projections.any? { |project_identifier, projection| projection[:not_likely].late? }
  end

  def start_delayed?
    if current_duration_percentage > 10
      projects.any? { |project| works.created_from(project).completed.empty? }
    end
  end

  def unique(identifier, candidate)
    return candidate if self.program.nil?
    Objective.unique(identifier, candidate, '', {:program_id => self.program.id})
  end

  def latest_date_in_objective
    forecast.latest_date || end_at
  end

  def ordered_snapshots(project)
    objective_snapshots.all(:conditions => ["project_id = ? and dated >= ?", project.id, start_at], :order => :dated)
  end

  def move_to_backlog
    backlog_objectives = program.objectives.backlog
    bottom_position = (backlog_objectives.maximum(:position) || 0).next
    attrs = {
        :start_at => nil,
        :end_at => nil,
        :vertical_position => nil,
        :status => Objective::BACKLOG,
        :position => bottom_position
    }
    self.works.destroy_all
    update_attributes(attrs)
    self
  end

  def update_attributes(attributes_value_hash)
    old_prop_values = self.attributes.slice('value', 'size')
    updated = super(attributes_value_hash)
    update_objective_property_value_mappings(old_prop_values, attributes_value_hash.slice('value', 'size')) if updated && connection.table_exists?('obj_prop_value_mappings') && !Rails.env.test?
    updated
  end

  private

  def t(table_name)
    ActiveRecord::Base.connection.safe_table_name(table_name)
  end

  def c(column_name)
    ActiveRecord::Base.connection.quote_column_name(column_name)
  end

  def create_objective_property_value_mappings
    return unless Rails.env.test?
    return unless connection.table_exists?('obj_prop_value_mappings')
    obj_value_prop_def_id = get_obj_prop_def_id(self.program_id, 'Value')
    obj_size_prop_def_id = get_obj_prop_def_id(self.program_id, 'Size')

    obj_value_prop_value_id = get_obj_prop_value_id(obj_value_prop_def_id, self.value)
    obj_size_prop_value_id = get_obj_prop_value_id(obj_size_prop_def_id, self.size)

    insert_into_obj_prop_value_mappings(obj_value_prop_value_id, self.id)
    insert_into_obj_prop_value_mappings(obj_size_prop_value_id, self.id)
  end

  def update_objective_property_value_mappings(old_prop_values,new_prop_values)
    return if new_prop_values.empty?
    obj_value_prop_def_id = get_obj_prop_def_id(self.program_id, 'Value')
    obj_size_prop_def_id = get_obj_prop_def_id(self.program_id, 'Size')

    old_value_prop_value_id = get_obj_prop_value_id(obj_value_prop_def_id, old_prop_values['value'])
    new_value_prop_value_id = get_obj_prop_value_id(obj_value_prop_def_id,new_prop_values['value'])
    old_size_prop_value_id = get_obj_prop_value_id(obj_size_prop_def_id, old_prop_values['size'])
    new_size_prop_value_id = get_obj_prop_value_id(obj_size_prop_def_id, new_prop_values['size'])

    value_sql = SqlHelper.sanitize_sql(
        "UPDATE #{t('obj_prop_value_mappings')} SET #{c('obj_prop_value_id')} = ?, #{c('updated_at')} = ?
              WHERE #{c('objective_id')} = ? AND #{c('obj_prop_value_id')} = ?",
        new_value_prop_value_id, Clock.now, self.id, old_value_prop_value_id

    )

    size_sql = SqlHelper.sanitize_sql(
        "UPDATE #{t('obj_prop_value_mappings')} SET #{c('obj_prop_value_id')} = ?, #{c('updated_at')} = ?
              WHERE #{c('objective_id')} = ? AND #{c('obj_prop_value_id')} = ?",
        new_size_prop_value_id, Clock.now, self.id, old_size_prop_value_id

    )
    connection.execute(value_sql)
    connection.execute(size_sql)
  end

  def delete_objective_property_value_mappings
    connection.execute(SqlHelper.sanitize_sql("DELETE FROM #{t('obj_prop_value_mappings')} WHERE #{c('objective_id')} = ?", self.id))
  end

  def get_obj_prop_value_id(obj_prop_def_id, obj_prop_value)
    connection.execute(SqlHelper.sanitize_sql("SELECT #{c('id')} FROM #{t('obj_prop_values')}
                                                  WHERE #{c('obj_prop_def_id')} = ? AND #{c('value')} = ?", obj_prop_def_id, obj_prop_value.to_s
    )).first['id']
  end

  def get_obj_prop_def_id(program_id, obj_prop_name)
    connection.execute(SqlHelper.sanitize_sql("SELECT #{c('id')} FROM #{t('obj_prop_defs')}
                          WHERE #{c('program_id')} = ? AND #{c('name')} = ?", program_id, obj_prop_name
    )).first['id']
  end

  def insert_into_obj_prop_value_mappings(obj_value_prop_value_id, objective_id)
    sql = SqlHelper.sanitize_sql("INSERT INTO #{t('obj_prop_value_mappings')} (id, objective_id, obj_prop_value_id, created_at, updated_at)
                                    VALUES(#{ActiveRecord::Base.connection.next_id_sql("#{ActiveRecord::Base.table_name_prefix}obj_prop_value_mappings")} , ? , ? , ? , ? )",
                                 objective_id, obj_value_prop_value_id, Clock.now, Clock.now)


    connection.execute(sql)
  end

  def create_objective_deletion_version
    version_attributes = {:version => next_version,
            :vertical_position => vertical_position,
            :identifier => identifier,
            :value_statement => value_statement,
            :size => size,
            :value => value,
            :name => name,
            :start_at => start_at,
            :end_at => end_at,
            :modified_by_user_id => User.current.id,
            :number => number,
            :status => status,
            :program_id => program.id,
            :objective_type_id => objective_type_id}

    deletion_version = versions.create!(version_attributes)
  end

  def set_modified_by_user
    self.modified_by = User.current
  end

  def current_duration_percentage
    total_duration = end_at - start_at

    if total_duration == 0
      Clock.today > end_at ? 100 : 0
    else
      current_duration = Clock.today - start_at
      current_duration * 100 / total_duration
    end
  end

  def generate_identifier
    candidate = name.gsub(ALLOWED_CHARACTERS_IN_IDENTIFIER, '_').downcase
    if candidate =~ /^\d.*/
      candidate = "objective_" + candidate
    end
    self.identifier = self.unique(:identifier, candidate)
  end

  def delete_works
    self.program.projects_with_work_in(self).each do |project|
      SyncObjectiveWorkProcessor.enqueue(project.id)
    end

    works.bulk_delete
    \
  end

  def resize_plan_to_accomodate_objective
    attributes_to_update = {}
    attributes_to_update.merge! :start_at => start_at if program.plan.start_at > start_at
    attributes_to_update.merge! :end_at => end_at if program.plan.end_at < end_at

    program.plan.update_attributes(attributes_to_update) if attributes_to_update.any?
  end

  def end_at_date_should_be_after_start_at_date
    errors.add(:end_at, "should be after start date") if self.start_at > self.end_at
  end

  def assign_number
    self.number = program.next_objective_number
  end

  def default_to_top_position
    all = self.status.match(BACKLOG) ? program.objectives.backlog : program.objectives.planned
    update_attribute(:position, 1)
    others = all - [self]
    others.each_with_index do |backlog_objective, index|
      backlog_objective.update_attribute(:position, index + 2)
    end
  end

  def update_positions
    all = self.status.match(BACKLOG) ? program.objectives.backlog : program.objectives.planned
    all.after(self).each do |backlog_objective|
      backlog_objective.update_attribute(:position, backlog_objective.position - 1)
    end
  end
end


class Objective::Version < ActiveRecord::Base
  after_create :fire_create_event

  belongs_to :modified_by, :class_name => '::User', :foreign_key => 'modified_by_user_id'
  belongs_to :program
  belongs_to :objective_type
  has_one :event, :as => :origin, :class_name => '::Event'

  validates_presence_of :objective_type

  NULL = Null.instance(:tags => [], :attachments => [])

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
    Event.with_program_scope(program_id, updated_at, user_id) do
      if Objective.find_by_identifier_and_program_id(identifier, program_id).present?
        Event.objective_version(self)
      else
        Event.objective_deletion(self)
      end
    end
  end
end
