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

class Dependency < ActiveRecord::Base
  include DependenciesHelper
  include Dependency::RenderablePolyfill
  include Dependency::MessageProviderPolyfill
  include Dependency::IndexableDependencyMethods

  include Renderable
  include Messaging::MessageProvider
  include DependencyJson
  include DependencyMethods

  acts_as_versioned_ext :association_options => {:order => 'version'}, :keep_versions_on_destroy => false
  acts_as_attachable

  belongs_to :raising_project, :class_name => 'Project', :foreign_key => "raising_project_id"
  belongs_to :resolving_project, :class_name => 'Project', :foreign_key => "resolving_project_id"
  belongs_to :raising_user, :class_name => 'User', :foreign_key => "raising_user_id"
  has_many :dependency_resolving_cards, :as => :dependency, :class_name => 'DependencyResolvingCard', :dependent => :destroy

  named_scope :all_for, lambda { |project|
    {:conditions => ["raising_project_id = ? or resolving_project_id = ?", project.id, project.id]}
  }

  named_scope :from_raising_card, lambda { |card|
    {:conditions => ["raising_card_number = ? and raising_project_id = ?", card.number, card.project_id]}
  }

  validate :raising_card_exists?
  validates_presence_of :raising_card_number
  validates_presence_of :name
  validates_presence_of :desired_end_date
  validates_presence_of :raising_project_id
  validates_presence_of :resolving_project_id, :on => :create
  validates_uniqueness_of :number

  before_validation_on_create :assign_number, :set_raising_user

  NEW = "NEW".freeze
  ACCEPTED = "ACCEPTED".freeze
  RESOLVED = "RESOLVED".freeze

  METHODS_TO_INDEX = [:number_and_name, :raised_by_project, :resolved_by_project, :raised_by_card, :resolved_by_cards]
  elastic_searchable :json => { :only => [:name, :status, :raising_project_id, :raising_card_number, :resolving_project_id, :desired_end_date],
                                :include => {
                                  :raising_user => {:only => [:name, :email, :login, :version_control_user_name]}
                                },
                                :methods => METHODS_TO_INDEX },
                     :merge => {
                        "depnum" => Proc.new {|model| model.prefixed_number},
                        "description" => Proc.new {|model| model.indexable_content},
                        "desired_completion_date" => Proc.new {|model| model.desired_end_date}
                     },
                     :type => "dependencies",
                     :index_name => Proc.new { ElasticSearch.index_name }

  def prefixed_number
    "D#{number}"
  end

  def self.comparator(attribute, direction)
    lambda {|a, b|
      a = a.send(attribute.to_sym)
      b = b.send(attribute.to_sym)


      if a.is_a?(String)
        a = a.try(:downcase)
        b = b.try(:downcase)
      elsif a.is_a?(Project) || a.is_a?(User)
        a = a.try(:name)
        b = b.try(:name)
      end

      if direction == "asc"
        if a.nil? && b.nil?
          0
        elsif a.nil?
          -1
        elsif b.nil?
          1
        else
          a <=> b
        end
      else
        if a.nil? && b.nil?
          0
        elsif a.nil?
          1
        elsif b.nil?
          -1
        else
          b <=> a
        end
      end
    }
  end

  def toggle_resolved_status
    new_status = if self.status == ACCEPTED
                   RESOLVED
                 elsif self.dependency_resolving_cards.empty?
                   NEW
                 else
                   ACCEPTED
                 end
    update_attribute(:status, new_status)
  end

  def recalculate_status
    return RESOLVED if self.status == RESOLVED

    total = dependency_resolving_cards.reload.count
    return NEW if total == 0
    ACCEPTED
  end

  def resolving_card_numbers
    return [] unless resolving_project
    resolving_project.with_active_project do |project|
      dependency_resolving_cards.map(&:card_number).map do |card_number|
        "##{card_number}"
      end
    end
  end

  def resolving_cards
    return [] unless resolving_project
    resolving_project.with_active_project do |project|
      dependency_resolving_cards.map(&:card_number).inject([]) do |memo, card_number|
        card = project.cards.find_by_number(card_number)
        memo << card unless card.blank?
        memo
      end
    end
  end

  def link_resolving_cards(cards)
    resolving_project.with_active_project do |project|
      cards.each do |card|
        unless self.dependency_resolving_cards.find_by_card_number(card.number).present?
          self.dependency_resolving_cards.create!(:card_number => card.number, :project_id => project.id)
        end
      end
      self.status = recalculate_status
    end
    self.save
  end

  def unlink_resolving_card_by_number(card_number)
    resolving_project.with_active_project do |project|
      self.dependency_resolving_cards = dependency_resolving_cards.select do |resolving_card|
        should_keep = resolving_card.card_number != card_number
        resolving_card.destroy unless should_keep
        should_keep
      end
    end
    self.status = recalculate_status
    self.save
  end

  def short_description
    "Dependency: #{prefixed_number} #{self.name}"
  end

  def to_json_with_formatted_date(date_format_context)
    self.as_json.merge({
      :status => self.status,
      :desired_end_date => formatted_date(desired_end_date, date_format_context)
    })
  end

  def history_events(pagination_options={})
    full_versioned_class = "#{self.class}::#{self.versioned_class_name}".constantize
    earliest_available_version = full_versioned_class.minimum(:version, :conditions => ["#{full_versioned_class.quoted_table_name}.#{self.class.versioned_foreign_key} = #{self.id}"]) || 0
    full_versioned_class.find(:all,
         :select => "#{full_versioned_class.quoted_table_name}.*, CASE WHEN #{full_versioned_class.quoted_table_name}.version = #{earliest_available_version} THEN 1 ELSE 0 END AS earliest_available_version",
         :include => [:events, {:events => [:changes, :created_by]}],
         :conditions => [
           "#{full_versioned_class.quoted_table_name}.#{self.class.versioned_foreign_key} = #{self.id}"].compact.join(' AND '),
         :order => "#{full_versioned_class.quoted_table_name}.version DESC")
  end

  private

  def assign_number
    seq = Sequence.find_table_sequence('dependency_numbers')
    return if self.number

    next_number = seq.next
    if Dependency.find_by_number(next_number).blank?
      self.number = next_number
    else
      assign_number
    end
  end

  def set_raising_user
    self.raising_user_id = User.current.id
  end

  def raising_card_exists?
    raising_project.with_active_project do |project|
      unless project.cards.exists?(:number => raising_card_number)
        self.errors.add_to_base("Raising Card doesn't exist")
      end
    end
  end

  def clone_versioned_model_with_associations(dependency, version)
    clone_versioned_model_without_associations dependency, version
    clone_resolving_cards dependency, version
    clone_attachings dependency, version
  end
  alias_method_chain :clone_versioned_model, :associations

  def clone_resolving_cards(dependency, version)
    version.dependency_resolving_cards = dependency.dependency_resolving_cards.map do |drc|
      DependencyResolvingCard.new(:card_number => drc.card_number, :project_id => drc.project_id)
    end
  end

  # override versioning criteria to compare itself to the last version in the database
  def altered?
    last_version = versions.find(:first, :conditions => ["version = ?", version])
    return true unless last_version
    ignored_attributes = ['id', 'created_at', 'raising_user_id', 'created_by_user_id']  + self.class.non_versioned_columns
    html_attributes = ['description', 'name', 'status']
    attributes_changed = (self.changed - ignored_attributes - html_attributes).reject { |attr_name| self.changes[attr_name].all?(&:blank?) }.any?
    html_attributes_changed = html_attributes.any? do |html_attribute|
      self.send(html_attribute).to_s.strip != last_version.send(html_attribute).to_s.strip
    end
    other_attributes = ['raising_project_id', 'resolving_project_id', 'dependency_resolving_cards']
    other_attributes_changed = other_attributes.any? do |attribute|
      self.send(attribute) != last_version.send(attribute)
    end
    attributes_changed || html_attributes_changed || other_attributes_changed || attachments_changed_against?(last_version)
  end
end

class Dependency::Version < ActiveRecord::Base
  include DependenciesHelper
  include Dependency::RenderablePolyfill
  include Dependency::MessageProviderPolyfill

  include Renderable
  include Messaging::MessageProvider
  include DependencyJson
  include DependencyMethods

  acts_as_attachable

  belongs_to :dependency
  belongs_to :raising_project, :class_name => 'Project', :foreign_key => "raising_project_id"
  belongs_to :resolving_project, :class_name => 'Project', :foreign_key => "resolving_project_id"
  belongs_to :raising_user, :class_name => 'User', :foreign_key => "raising_user_id"
  has_many :dependency_resolving_cards, :as => :dependency, :dependent => :destroy
  has_many :events, :as => :origin, :class_name => '::Event', :dependent => :destroy

  after_create :create_events

  NULL = Null.instance(:dependency_resolving_cards => [], :attachments => [])

  class << self
    def load_history_event(project, ids)
      [].tap do |versions|
        ids.each_slice(ORACLE_BATCH_LIMIT) do |chunk_of_ids|
          versions << all(:include => [:dependency, :events],
                          :conditions => ["(#{self.table_name}.raising_project_id = ? or #{self.table_name}.resolving_project_id = ?) and #{self.table_name}.id in (#{chunk_of_ids.join(',')})", project.id, project.id])
        end
      end
    end
  end

  def prefixed_number
    "D#{number}"
  end

  def create_events
    Event.with_project_scope(self.raising_project_id, Clock.now, User.current.id) do
      Dependency.exists?(dependency_id) ? Event.dependency_version(self) : Event.dependency_deletion(self)
    end
    if self.resolving_project_id && self.raising_project_id != self.resolving_project_id
      Event.with_project_scope(self.resolving_project_id, Clock.now, User.current.id) do
        Dependency.exists?(dependency_id) ? Event.dependency_version(self) : Event.dependency_deletion(self)
      end
    end
  end

  def changes
    event ? event.changes : []
  end

  def previous
    self.class.find(:first, :conditions => ["dependency_id = ? AND version < ?", self.dependency_id, version], :order => 'version DESC')
  end

  def first_version
    self.class.minimum(:version, :conditions => ['dependency_id = ?', self.dependency_id])
  end

  def first?
    self.version == first_version
  end

  def latest_version?
    self.version == latest_version
  end

  def latest_version
    self.class.find(:first, :conditions => ["dependency_id = ?", self.dependency_id], :order => 'version DESC').version
  end

  def formatted_desired_end_date
    Project.current.format_date(desired_end_date) if Project.current_or_nil
    raising_project.format_date(desired_end_date)
  end

  def details_still_loading?
    if !event
      create_events
      self.reload.event
    else
      return false
    end
    event.details_still_loading?
  end

  def event
    self.events.detect{|e| e.deliverable_id == self.raising_project_id}
  end

  def event_type
    :dependency_version
  end

  def resolving_cards
    return [] unless resolving_project
    resolving_project.with_active_project do |project|
      dependency_resolving_cards.map do |drc|
        project.cards.exists?(:number => drc.card_number) ? project.cards.find_by_number(drc.card_number) : Card::Version.find_by_number(drc.card_number)
      end
    end
  end
end
