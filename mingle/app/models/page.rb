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

module PageMethods

  def this_card_condition_availability
    ThisCardConditionAvailability::Never.new(self)
  end

  def this_card_condition_error_message(usage)
    "#{usage.bold} is not a supported macro for page."
  end

  def daily_history_chart_url(view_helper, params)
    return view_helper.daily_history_chart_for_page_url(params.merge(:pagename => identifier)) if latest_version?
    view_helper.daily_history_chart_for_unsupported_url({:position => params[:position], :unsupported_content_provider => 'a page version'})
  end

  def identifier
    Page.name2identifier(name)
  end

  def process_macros?; true; end

  def to_s
    "#{self.class}[name => #{name}, version => #{version}, project_id => #{project_id}]"
  end
end

class Page < ActiveRecord::Base
  include PageMethods, Messaging::MessageProvider
  include Renderable
  include PathSanitizer
  acts_as_traceable { User.current }
  acts_as_versioned_ext :association_options => {:include => [{:taggings => :tag}, :modified_by, :event], :order => "version"}, :keep_versions_on_destroy => true
  acts_as_taggable
  acts_as_attachable
  use_database_limits_for_all_attributes

  v1_serializes_as :id, :identifier, :name, :content, :project_id, :created_at, :updated_at, :created_by_user_id, :modified_by_user_id, :version
  v2_serializes_as :complete => [:id, :identifier, :name, :content, :project, :created_at, :updated_at, :created_by, :modified_by, :version, :rendered_description]
  compact_at_level 0

  elastic_searchable :json => { :only => [:name],
                                :include => { :created_by => {:only => [:name, :email, :login, :version_control_user_name]},
                                              :modified_by => {:only => [:name, :email, :login, :version_control_user_name]}},
                                :methods => [:tag_names, :project_id, :indexable_content]},
                     :index_name => Project.index_name

  belongs_to :project
  has_many :favorites, :as => :favorited, :dependent => :destroy
  named_scope :order_by_name, :order => 'lower(name)'

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => 'project_id', :case_sensitive => false
  before_destroy :check_current_user_is_project_admin, :destroy_subscriptions
  after_destroy :create_deletion_page_version

  self.resource_link_route_options = proc {|page| {} }
  self.resource_link_route_options_for_xml = proc {|page| { :page_identifier => page.identifier } }
  self.resource_link_route_options_for_html = proc {|page| { :pagename => page.name } }

  def clone_versioned_model_with_associations(original_model, new_model)
    clone_versioned_model_without_associations original_model, new_model
    clone_taggings(original_model, new_model)
    clone_attachings(original_model, new_model)
  end

  alias_method_chain :clone_versioned_model, :associations

  def self.validate_page_name(name)
    error = if name.strip.include? '/'
      "The page name #{name.escape_html} contains at least one invalid character."
    elsif name.size > 255
      "The page name is too long."
    else
      nil
    end
  end

  def self.find_by_identifier(identifier)
    return unless identifier
    find(:first, :conditions => ["LOWER(name) = ? OR name = ?", identifier2name(identifier).downcase, identifier2name(identifier)])
  end

  def self.page_exists?(identifier)
    return if identifier.blank?
    count(:conditions => ["LOWER(name) = ? OR name = ?", identifier2name(identifier).downcase, identifier2name(identifier)]) > 0
  end

  def identifier=(identifier)
    self.name = Page.identifier2name(identifier)
  end

  def short_description
    if name.downcase =~ /page$/
      name
    else
      "#{name} page"
    end
  end

  def overview_page?
    return identifier == Project::OVERVIEW_PAGE_IDENTIFIER
  end

  def export_dir
    sanitize name
  end

  def attribute?(symbol)
    self.class.content_columns.collect(&:name).include?(symbol.to_s)
  end

  def changed?(attribute=nil)
    return true if versions.empty?
    last_version = versions.last
    excluded =  ['id', 'updated_at', 'created_at', 'has_macros', 'created_by_user_id', 'modified_by_user_id']
    html_attributes = ['content']
    attributes_changed = (attribute_names - excluded - html_attributes).any? do |attribute|
      self.send(attribute) != last_version.send(attribute)
    end
    html_attributes_changed = html_attributes.any? do |html_attribute|
      self.send(html_attribute).to_s.strip != last_version.send(html_attribute).to_s.strip
    end
    current_tags = self.tags.collect(&:name)
    last_tags = last_version.tags.collect(&:name)
    tags_changed = !((current_tags - last_tags).empty? and (last_tags - current_tags).empty?)

    attributes_changed or html_attributes_changed or tags_changed or attachments_changed_against? last_version
  end

  def find_events_since(last_max_ids)
    versions.select {|v| v.id > last_max_ids[:page_version].to_i}
  end

  def destroy_subscriptions
    self.project.history_subscriptions.select { |s| s.is_page_subscription?(self) }.each(&:destroy)
  end

  def check_current_user_is_project_admin
    raise UserAccess::NotAuthorizedException.new('Not allowed.') unless self.project.admin?(User.current)
  end

  def latest_version?
    self.version == self.versions.maximum(:version)
  end

  def latest_version
    @lv ||= find_version(self.version)
  end

  def tags_for_indexing #simulates eager loading of tags when searchable is polymorphically loaded
    res = ActiveRecord::Base.connection.select_all %{
      SELECT t.name AS name, t.id AS id
      FROM
        #{Page.table_name} p
        JOIN taggings tgg ON (tgg.taggable_id = p.id AND tgg.taggable_type = 'Page')
        JOIN tags t ON (tgg.tag_id = t.id)
      WHERE
        p.id = #{self.id}
        AND p.project_id = #{project.id}
    }
    res.collect do |row|
      OpenStruct.new(:term_string => row['name'], :associated_type => Tag.name, :associated_id => row['id'], :attribute_name => 'tags.name')
    end
  end

  def tag_names
    tags_for_indexing.map(&:term_string)
  end

  def history_events(pagination_options={})
    self.versions_with_eager_loads_for_history_performance
  end

  def Page.identifier2name(identifier)
    return unless identifier
    identifier.gsub(/_/, ' ')
  end

  def Page.name2identifier(name)
    return unless name
    name.gsub(/ /, '_')
  end

  def to_params
    {:page_identifier => self.identifier}
  end
  memoize :to_params, :return_clone => true

  def link_params
    to_params.merge({:controller => 'pages'})
  end

  def style
    'wiki'
  end
  alias_method :style_description, :style

  def tabbable?
    true
  end

  def create_deletion_page_version
    versions.create!(:name => name,
                     :project_id => project.id,
                     :version => next_version,
                     :created_by_user_id => User.current.id,
                     :modified_by_user_id => User.current.id)
  end

  def chart_executing_option
    {
      :controller => 'pages',
      :action => 'chart',
      :pagename => identifier
    }
  end

end

class Page::Version < ActiveRecord::Base
  include PageMethods
  include Renderable
  include PathSanitizer
  belongs_to :project, :class_name => '::Project', :foreign_key => 'project_id'
  belongs_to :created_by, :class_name => '::User', :foreign_key => 'created_by_user_id'
  belongs_to :modified_by, :class_name => '::User', :foreign_key => 'modified_by_user_id'
  has_one :event, :as => :origin, :class_name => '::Event', :dependent => :destroy
  acts_as_taggable
  acts_as_attachable
  after_create :create_event

  v1_serializes_as :complete => [:id, :identifier, :name, :content, :project_id, :created_at, :updated_at, :created_by_user_id, :modified_by_user_id, :version],
                  :element_name => 'page-version'
  v2_serializes_as :complete => [:id, :identifier, :name, :content, :project, :created_at, :updated_at, :created_by, :modified_by, :version, :rendered_description],
                  :element_name => 'page'
  compact_at_level 0

  self.resource_link_route_options = proc {|page_version| { :version => page_version.version } }
  self.resource_link_route_options_for_xml = proc {|page_version| { :page_identifier => page_version.identifier } }
  self.resource_link_route_options_for_html = proc {|page_version| { :pagename => page_version.name } }
  self.routing_name = "page"

  def versioned
    page
  end

  def export_dir
    sanitize name
  end

  NULL = Null.instance(:tags => [], :attachments => [])

  class << self
    def load_history_event(project, ids)
      [].tap do |versions|
        ids.each_slice(ORACLE_BATCH_LIMIT) do |chunk_of_ids|
          versions << all(:include => [:modified_by, :page, {:taggings => :tag, :attachings => :attachment, :event => :changes}],
                          :conditions => ["#{self.table_name}.project_id = ? and #{self.table_name}.id in (#{chunk_of_ids.join(',')})", project.id])
        end
      end
    end
  end

  def resource_link_title
    "#{name} (v#{version})"
  end

  def first?
    version == first_version
  end

  def event_type
    :page_version
  end

  def latest_version?
    self.class.count(:conditions => ["page_id = ? AND version > ?", self.page_id, self.version]) == 0
  end

  def tag_additions
    changes.collect(&:added_tag).compact
  end

  def tag_deletions
    changes.collect(&:removed_tag).compact
  end

  def chart_executing_option
    {
      :controller => 'pages',
      :action => 'chart',
      :pagename => identifier,
      :version => version
    }
  end

  def successor_to?(event)
    self.event_type == event.event_type and #same kind of event
    self.version - 1 == event.version and #one version ago
    self.page_id == event.page_id #on the same reference object
  end

  def previous
    self.class.find(:first, :conditions => ["page_id = ? AND version < ?", self.page_id, version], :order => 'version DESC')
  end

  def describe_changes
    changes.collect(&:describe).compact
  end

  def create_event
    Event.with_project_scope(project_id, updated_at, modified_by_user_id) do
      project.pages.exists?(page_id) ? Event.page_version(self) : Event.page_deletion(self)
    end
  end

  def details_still_loading?
    (event || create_event && self.reload.event).details_still_loading?
  end

  def changes
    event.changes
  end

  def page_resource_link
    Page.resource_link(name, {}, {:page_identifier => identifier}, {:pagename => name})
  end

  protected

  def first_version
    self.class.minimum(:version, :conditions => ['page_id = ?', self.page_id])
  end

end
