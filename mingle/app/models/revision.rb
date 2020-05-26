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

class Revision < ActiveRecord::Base
  include Messaging::MessageProvider

  belongs_to :project
  has_many :card_revision_links, :dependent => :destroy
  has_many :changes, :as => :version, :class_name => '::Change', :dependent => :destroy
  has_one :event, :as => :origin, :class_name => '::Event', :dependent => :destroy
  validates_uniqueness_of :number, :scope => [:project_id]
  validates_uniqueness_of :identifier, :scope => [:project_id]

  before_save :truncate_commit_message
  after_create :create_event

  self.resource_link_route_options = proc {|rev| { :rev => rev.identifier } }


  def self.create_from_repository_revision(revision, project)
    if revision.time
      identifier = (revision.respond_to?(:identifier) ? revision.identifier : revision.number).to_s
      number = revision.respond_to?(:number) ? revision.number.to_i : project.revisions.maximum(:number).to_i + 1
      result = find_or_create(
              :identifier => identifier,
              :number => number,
              :commit_message => revision.message || '',
              :commit_time => revision.time.utc,
              :commit_user => revision.version_control_user || '',
              :project_id => project.id)
      result.create_card_links
      result
    else
      Rails.logger.info("Ignore revision #{revision.inspect}, as it does not have time stamp")
    end
  end

  def self.find_or_create(attributes)
    unique_attributes = {:project_id => attributes[:project_id], :number => attributes[:number], :identifier => attributes[:identifier]}
    find(:first, :conditions => unique_attributes) || create!(attributes)
  end

  def self.delete_for(project)
    project = Project.find(project) unless project.respond_to?(:identifier)
    revision_to_be_deleted_count = project.revisions.count
    Revision.connection.execute("DELETE FROM #{CardRevisionLink.table_name} WHERE project_id = #{project.id}")
    Revision.connection.execute("DELETE FROM #{Change.table_name} WHERE event_id IN (SELECT id FROM #{Event.table_name} WHERE deliverable_id = #{project.id} AND type = 'RevisionEvent')")
    Revision.connection.execute("DELETE FROM #{Event.table_name} WHERE deliverable_id = #{project.id} AND type = 'RevisionEvent'")
    Revision.connection.execute("DELETE FROM #{Revision.table_name} WHERE project_id = #{project.id}")

    CorrectionEvent.create_for_repository_settings_change(project) if revision_to_be_deleted_count > 0
  end

  class << self
    def load_history_event(project,ids)
      return [] unless project.has_source_repository?
      [].tap do |revisions|
        ids.each_slice(ORACLE_BATCH_LIMIT) do |chunk_of_ids|
          revisions << self.find(:all, :include => [:event, :project], :conditions => ["#{self.table_name}.project_id = ? and #{self.table_name}.id in (#{chunk_of_ids.join(',')})", project.id])
        end
      end
    end
  end

  def mingle_user
    project.version_control_users[self.commit_user]
  end

  def due_to_user?(user)
    return self.mingle_user.name.include?(user) if self.mingle_user
    self.commit_user == user
  end

  def include?(term)
    return false if term.nil? or term.blank?
    [commit_user, commit_message].any? do |item|
      item.to_s.upcase.include?(term.upcase)
    end || number.to_s == term || due_to_user?(term)
  end

  def user
    if mingle_user
      mingle_user.name
    else
      commit_user
    end
  end

  def changed_paths
    project.repository_revision(self.number).changed_paths
  end

  def updated_at
    commit_time
  end

  def event_type
    :revision
  end

  def first?
    number == self.project.revisions.minimum('number')
  end

  def last?
    number == self.project.revisions.maximum('number')
  end

  def previous_revision_identifier
    first? ? nil : self.project.revisions.find(:first, :conditions => "#{Project.connection.quote_column_name('number')} < #{number}", :order => "#{Project.connection.quote_column_name('number')} desc").identifier
  end

  def next_revision_identifier
    last? ? nil : self.project.revisions.find(:first, :conditions => "#{Project.connection.quote_column_name('number')} > #{number}", :order => "#{Project.connection.quote_column_name('number')} asc").identifier
  end

  def short_identifier
    return identifier unless project.has_source_repository?
    if length = project.repository_vocabulary['short_identifier_length']
      identifier.truncate_with_ellipses(length.to_i)
    else
      identifier
    end
  end

  def short_name
    return "#{default_repository_vocabulary['revision'].titleize} #{short_identifier}" unless project.has_source_repository?
    "#{project.repository_vocabulary['revision'].titleize} #{short_identifier}"
  end

  def name
    return "#{default_repository_vocabulary['revision'].titleize} #{identifier}" unless project.has_source_repository?
    "#{project.repository_vocabulary['revision'].titleize} #{identifier}"
  end

  def description
    return "#{short_name} #{default_repository_vocabulary['committed']} by #{user}" unless project.has_source_repository?
    "#{short_name} #{project.repository_vocabulary['committed']} by #{user}"
  end

  def default_repository_vocabulary
    {
      'change list' => 'revision',
      'revision' => 'revision',
      'committed' => 'committed',
      'repository' => 'repository'
    }
  end

  def tag_additions
    []
  end

  def property_changes
    []
  end

  def describe_changes
    changes.collect(&:describe).compact
  end

  def changes
    event ? event.changes : []
  end

  def create_event
    project.with_active_project do |p|
      created_by_user_id = mingle_user ? mingle_user.id : nil
      Event.with_project_scope(p.id, commit_time, created_by_user_id) do
        Event.revision(self)
      end
    end
  end

  def generate_changes
    if event
      Event.lock_and_generate_changes!(event.id)
    else
      create_event
    end
  end

  def project
    Project.current
  end

  def cards
    project.cards.find(card_revision_links.collect(&:card_id))
  end

  def create_card_links
    card_revision_links.destroy_all
    card_numbers = project.card_keywords.card_numbers_in(self.commit_message)
    if card_numbers.any?
      card_ids = Card.connection.select_all("SELECT id from #{Card.quoted_table_name} WHERE #{connection.quote_column_name('number')} IN (#{card_numbers.join(',')})").map{|row| row['id'].to_i}
      card_ids.each do |card_id|
        CardRevisionLink.create!(:project_id => project.id, :card_id => card_id, :revision_id => self.id)
      end
    end
  end

  def to_s
    "Revision[number => #{number}, project_id => #{project_id}]"
  end

  def commit_message_not_longer_than_255
    boundary = 85
    boundary += 1 until (boundary > commit_message.mb_chars.size) || (commit_message.mb_chars[0..boundary].to_str.length > 255)
    commit_message.mb_chars[0...boundary].to_str
  end

  def update_created_by
    self.event.update_attribute(:created_by_user_id, mingle_user ? mingle_user.id : nil)
  end

  private

  def truncate_commit_message
    self.commit_message = self.commit_message.slice(0..(65535-1))
  end

end
