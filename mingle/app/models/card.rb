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

class Card < ActiveRecord::Base
  include Card::DefaultAttributeMethods
  extend Card::ThreadSafe::CardTableName
  extend Card::ThreadSafe::Columns
  include Renderable
  include CardMethods
  include CardTreeMethods
  include CardFinder
  include CardJson
  include Messaging::MessageProvider
  include Card::Dependencies

  STANDARD_PROPERTIES = ['Number', 'Name', 'Description', CardTypeDefinition::INSTANCE.name]

  belongs_to :project
  has_many :card_revision_links, :dependent => :destroy
  has_many :revisions, :through => :card_revision_links, :order => "revisions.id DESC, commit_time DESC"
  has_many :card_murmur_links
  has_many :murmurs, :through => :card_murmur_links, :include => :author, :order => 'created_at DESC'
  has_many :origined_murmurs, :class_name => "CardCommentMurmur", :foreign_key => :origin_id, :conditions => {:origin_type => 'Card'}, :order => 'id ASC'

  has_many :checklist_items, :dependent => :destroy, :order => "position ASC, updated_at DESC, id DESC", :class_name => 'CardChecklistItem'

  validates_presence_of :name
  validates_uniqueness_of :number
  validates_presence_of :card_type_name

  validate :do_card_type_validation
  validate :do_plv_usage_checking_on_card_type_change
  validate :do_transition_usage_checking_on_card_type_change
  validate :do_validate_not_applicable_properties
  validate :do_validate_updating_properties_existing

  before_create :assign_number, :generate_id

  before_save :set_not_applicable_properties_to_nil, :compute_formulas, :convert_tab_character_to_space_in_description, :clear_previous_version_or_nil, :normalize_card_type_name

  # AR stuff for card_tree_methods but which can't be there due to circular dependency
  has_many :tree_belongings
  has_many :tree_configurations, :through => :tree_belongings
  before_save :revise_belonging_tree_structure

  # end stuff for card_tree_methods

  # this defines an after_save that saves the version, and some of our callbacks use that version -- so this line should come before our other after_save definitions
  acts_as_versioned_ext :association_options => {:order => 'version'}, :keep_versions_on_destroy => true
  remove_reflection_table_name_cache(:versions)
  include Card::ThreadSafe::ActsAsVersionedFix

  after_save :repair_trees, :trigger_instance_callbacks,
    :compute_aggregate_properties_on_property_change, :recompute_aggregate_if_card_type_changed,
    :remove_tree_belonging_on_card_type_name_attribute_changed


  before_destroy do |card|
    CardSelection.new(card.project, [card]).destroy(:include_associations_rails_knows_about => false)
  end

  v1_serializes_as :api_attributes

  COMPLETE_SERIALIZATION_ATTRIBUTES = [:name, :description, :card_type, :id, :number, :project, :version, :project_card_rank, :created_on, :modified_on, :modified_by, :created_by, [:property_values_with_hidden, {:element_name => 'properties'}], [:tag_summary, {:element_name => 'tags'}], :rendered_description]
  COMPLETE_SERIALIZATION_ATTRIBUTES_WITH_TRANSITION_IDS = COMPLETE_SERIALIZATION_ATTRIBUTES + [:transition_ids]
  v2_serializes_as :complete => COMPLETE_SERIALIZATION_ATTRIBUTES, :slack => COMPLETE_SERIALIZATION_ATTRIBUTES_WITH_TRANSITION_IDS, :compact => [:number]

  compact_at_level 0

  after_destroy :create_card_deletion_version

  include CardRanking
  non_versioned_columns << CardRanking::RANK_COLUMN << 'caching_stamp'

  acts_as_taggable
  acts_as_traceable { User.current }
  acts_as_attachable

  METHODS_TO_INDEX = [:number_and_name, :tag_names, :checklist_items_texts, :discussion_for_indexing, :card_type_id, :tree_configuration_ids, :indexable_content, :properties_to_index, :raises_dependencies, :resolves_dependencies]

  elastic_searchable :json => { :only => [:name, :number, :project_id, :card_type_name],
                                :include => {
                                  :created_by => {:only => [:name, :email, :login, :version_control_user_name]},
                                  :modified_by => {:only => [:name, :email, :login, :version_control_user_name]}
                                },
                                :methods => METHODS_TO_INDEX },
                     :type => "cards",
                     :index_name => ::Project.index_name

  strip_on_write :except => [:description]
  use_database_limits_for_all_attributes(:except => [:project_card_rank])

  attr_accessor :system_generated_comment
  after_save :clear_comment

  skip_associated_after_update_callback_for :versions
  skip_associated_validation_for :versions

  self.resource_link_route_options = proc {|card| { :number => card.number } }

  alias :resource_link_title :type_and_number

  def self.santitize_card_id(id)
    return id.to_i if id.is_a?(String)
    return id.id if id.respond_to?(:quoted_id)
    id
  end

  def self.find_existing_or_deleted_card(card_id)
    card_id = santitize_card_id(card_id)
    find_by_id(card_id) ||
    find_deleted_card(card_id) ||
    raise(ActiveRecord::RecordNotFound, "cannot find card or card version with id #{card_id}")
  end

  def self.find_deleted_card(card_id)
    DeletedCard.new_from_last_version(santitize_card_id(card_id))
  end

  def self.build_with_defaults(attributes={}, properties={})
    attributes ||= {}
    properties ||= {}

    result = new
    result.card_type_name ||= attributes[:card_type] && attributes.delete(:card_type).name
    result.card_type_name ||= attributes.delete(:card_type_name)
    result.card_type_name ||= properties.delete_ignore_case('type')
    result.card_type ||= Project.current.card_types.first

    result.redcloth = false

    result.set_defaults(:set_errored_fields_to_not_set => true)
    result.update_properties properties, {:method => 'get', :honor_trees => true}
    result.attributes = attributes
    result
  end

  def clear_comment
    @comment_attributes = nil
  end

  def register_after_save_callback(&block)
    instance_callbacks(:after_save) << block
  end

  def trigger_instance_callbacks
    instance_callbacks(:after_save).each{ |callback| callback.call(self) }
  end

  def instance_callbacks(event_name)
    @instance_callbacks ||= {}
    @instance_callbacks[event_name] ||= []
  end

  def description=(str)
    @description_changed = true
    str.blank? ? write_attribute(:description, str) : write_attribute(:description, str.rstrip)
  end

  def self.highest_card_number
    Project.current.cards.maximum('number')
  end

  def self.find_or_initialize_by_number(number)
    return Card.new unless number
    find_by_sql(["select * FROM #{quoted_table_name} WHERE project_id = ? and #{Project.connection.quote_column_name('number')} = ?", Project.current.id, number]).first || Card.new(:number => number)
  end

  def self.find_by_numbers(numbers)
    self.find_by_numbers_with_eager_loading(numbers, nil)
  end

  def self.find_by_numbers_with_eager_loading(numbers, relationships)
    self.all(:conditions => ["#{Project.connection.quote_column_name('number')} IN (?)", numbers], :include => relationships)
  end

  def self.tag_condition_sql(project, tag_name)
    tag = Project.current.tags.detect{|tag| tag.name.downcase == tag_name.downcase}
    return "1 = 0" unless tag
    bind_variables ["#{Card.quoted_table_name}.id IN (SELECT taggable_id FROM taggings WHERE tag_id = ? AND taggable_type = 'Card')", tag.id]
  end

  def self.parse_and_sanitize_numbers_string(card_numbers_string)
    oracle_limit = 1000
    numbers = card_numbers_string.split(',').map(&:to_i)

    numbers_in_db = []
    numbers_sql = %{SELECT #{connection.quote_column_name('number')} FROM #{quoted_table_name} WHERE #{connection.quote_column_name('number')} IN (?)}
    numbers.each_slice(oracle_limit) do |sliced_numbers|
      numbers_in_db += connection.select_values(SqlHelper.sanitize_sql(numbers_sql, sliced_numbers))
    end
    numbers_in_db = numbers_in_db.collect(&:to_i)
    numbers.uniq.reject { |potential_card| !numbers_in_db.include?(potential_card) }
  end

  def update_properties(property_params, options = {})
    if options[:honor_trees]
      raise "Method must be get when honor_trees => true" if options[:method] != 'get'
      property_params = self.honor_trees_for(property_params)
    end
    @updating_prop_names = property_params.collect do |prop_name, prop_value|
      prop_name = prop_name.name if prop_name.kind_of?(PropertyDefinition)
      prop_name.to_s.downcase
    end
    property_params = nil_out_tree_relationships_if_card_type_is_only_thing_changed(property_params)
    PropertyValueCollection.from_params(project, property_params, options).assign_to(self, options)
  end

  def write_attribute_with_correcting_value(attr_name, attr_value)
    attr_name = attr_name.to_s
    if attr_name =~ /^cp_/ && !attr_value.blank? && prop = project.enum_property_definitions_with_hidden.detect {|pd| pd.column_name.ignore_case_equal?(attr_name)}
      attr_value = prop.correct_value(attr_value)
    end
    write_attribute_without_correcting_value(attr_name, attr_value)
  end

  alias_method_chain :write_attribute, :correcting_value

  def validate
    self.property_definitions_with_value.each do |prop|
      prop.validate_card(self)
    end
    remove_blocked_errors

    if validate_tree_fully?
      card_type.tree_configurations.each{ |configuration| configuration.validate_card_fully(self) }
    elsif !@original_values_of_changed_properties.blank?
      project.tree_configurations.each do |config|
        config.validate_card(self, @original_values_of_changed_properties[config.name]) if @original_values_of_changed_properties[config.name]
      end
    end
  end

  def card_type_name=(new_card_type_name)
    @old_card_type_name = self.card_type_name
    write_attribute(:card_type_name, new_card_type_name)
    clear_cached_results_for :card_type
  end

  def card_type=(new_card_type)
    self.card_type_name = new_card_type.name
  end

  def validate_not_applicable_properties=(validate)
    @validate_not_applicable_properties = validate
  end

  def validate_not_applicable_properties?
    @validate_not_applicable_properties ||= false
  end

  def name_of_attribute(attribute_name)
    return attribute_name if PropertyDefinition.predefined?(attribute_name)

    property_definition = self.project.property_definitions_including_type.detect{|pd| quoted_column_name(pd.ruby_name) == quoted_column_name(attribute_name)}
    return "#{property_definition.name}'s value" if property_definition
    attribute_name
  end

  def quoted_column_name(original_name)
    self.class.connection.quote_column_name(original_name)
  end

  def card_type_name
    super.blank? ? nil : super
  end



  def export_attributes(columns, options={:include_tags => true, :include_checklist_items => true})
    values = columns.collect{|column| project.find_property_definition(column).property_value_on(self).export_value }
    tag_values = tags.collect(&:name).sort.join(",")
    values << tag_values if options[:include_tags]
    if options[:include_checklist_items]
      values << incomplete_checklist_items.collect(&:text).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)
      values << completed_checklist_items.collect(&:text).join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)
    end
    values
  end

  # override versioning criteria to compare itself to the last version in the database
  def altered?
    return true if !comment.blank? || system_generated_comment
    last_version = versions.find(:first, :conditions => ["version = ?", version])
    return true unless last_version
    aggregate_property_attribute_names = project.aggregate_property_definitions_with_hidden.collect(&:column_name)
    ignored_attributes = ['id', 'updated_at', 'created_at', 'has_macros', 'created_by_user_id', 'modified_by_user_id']  + self.class.non_versioned_columns + aggregate_property_attribute_names
    html_attributes = ['description']
    attributes_changed = (self.changed - ignored_attributes - html_attributes).reject { |attr_name| self.changes[attr_name].all?(&:blank?) }.any?
    html_attributes_changed = html_attributes.any? do |html_attribute|
      self.send(html_attribute).to_s.strip != last_version.send(html_attribute).to_s.strip
    end
    current_tags = self.tags.collect(&:name)
    last_tags = last_version.tags.collect(&:name)
    tags_changed = !((current_tags - last_tags).empty? and (last_tags - current_tags).empty?)
    attributes_changed || html_attributes_changed || tags_changed || attachments_changed_against?(last_version)
  end

  def assign_name
    if number
      self.name = "Card #{number}"
    else
      self.name = "Untitled"
    end
  end

  def view_from(container)
    # TODO: This seems unused.
    params = container.to_params.merge(:filters => filters, :tagged_with => tags.join(','), :lanes => container.group_lanes.visibles(:lane).collect(&:identifier).join(','))
    CardListView.construct_from_params(project, params)
  end

  def filters
    project.property_definitions_including_type.collect do |property_def|
      Filters::Filter::encode(property_def.name, property_def.value(self)) if property_def.value(self)
    end.compact
  end

  def discussion
    Discussion.new(self)
  end

  def discussion_for_indexing
    comment_column = Card.connection.quote_column_name('comment')
    Card.connection.select_values %{
      SELECT #{comment_column}
      FROM #{Card::Version.quoted_table_name} v
      WHERE
        v.card_id = #{self.id}
        AND v.#{comment_column} IS NOT NULL
        AND v.project_id = #{project.id}
      ORDER BY
        v.version DESC
    }
  end

  def tags_for_indexing #simulates eager loading of tags when searchable is polymorphically loaded
    res = ActiveRecord::Base.connection.select_all %{
      SELECT t.name AS name, t.id AS id
      FROM
        #{Card.quoted_table_name} c
        JOIN taggings tgg ON (tgg.taggable_id = c.id AND tgg.taggable_type = 'Card')
        JOIN tags t ON (tgg.tag_id = t.id)
      WHERE
        c.id = #{self.id}
        AND c.project_id = #{project.id}
    }
    res.collect do |row|
      OpenStruct.new(:term_string => row['name'], :associated_type => Tag.name, :associated_id => row['id'], :attribute_name => 'tags.name')
    end
  end

  def tag_names
    tags_for_indexing.map(&:term_string)
  end

  def transition_ids
    self.transitions.map(&:id).join(',')
  end

  def checklist_items_texts
    checklist_items.map(&:text)
  end

  def properties_to_index
    property_definitions_with_hidden.inject({}) do |properties, property_definition|
      value = case property_definition
        when UserPropertyDefinition
          property_definition.indexable_value(self)
        when TextPropertyDefinition, EnumeratedPropertyDefinition
          read_attribute property_definition.column_name
        end
      if value
        properties[property_definition.name.downcase.to_sym] = value
      end
      properties
    end
  end

  def transitions
    project.transitions.select { |transition|
      transition.available_to?(self, User.current.api_user?)
    }.smart_sort_by(&:name)
  end

  def comments
    Cache.get(Keys::CardComments.new.path_for(self)) do
      if versions.loaded?
        all_comments_from_loaded_card_versions
      else
        all_comments
      end.sort_by(&:created_at).reverse
    end
  end

  def all_comments_from_loaded_card_versions
    versions.map(&:comment_details).compact.reject(&:blank?)
  end

  def all_comments_count
    versions.count(:conditions => ["#{quoted_column_name('comment')} IS NOT NULL"])
  end

  def all_comments
    cols = %w(card_id comment updated_at modified_by_user_id version).map {|c| quoted_column_name(c)}
    versions.find(:all,
        :select => cols.join(", "),
        :conditions => ["#{cols[1]} IS NOT NULL"]).
        map(&:comment_details)
   end

  def murmurs_with_caching
    Cache.get(Keys::CardMurmurs.new.path_for(self)) do
      murmurs_without_caching.to_a
    end
  end
  alias_method_chain :murmurs, :caching

  def add_comment(comment_attributes)
    self.comment = comment_attributes
    save!
    comment(comment_attributes)
  end

  def comment=(comment_attributes)
    @comment_attributes = comment_attributes
  end

  def comment(comment_attributes=@comment_attributes)
    Comment.new(self, comment_attributes || {})
  end

  def color(property_definition)
    return unless property_definition
    if property_definition.respond_to?(:color)
      property_definition.color(self)
    else
      color(project.find_property_definition_or_nil(property_definition))
    end
  end

  def find_events_since(last_max_ids)
    ret = versions.find(:all, :conditions => ["#{Card::Version.quoted_table_name}.id > ?", last_max_ids[:card_version].to_i])
    ret += self.revisions.find(:all, :conditions => ["#{Revision.quoted_table_name}.id > ?", last_max_ids[:revision].to_i]) unless project.skip_revision_notification?
    ret
  end

  def latest_version?
    true
  end

  def clone_versioned_model_with_associations(card, version)
    clone_versioned_model_without_associations card, version
    card.comment.store_to(version)
    version.system_generated_comment = card.system_generated_comment
    clone_taggings card, version
    clone_attachings card, version
  end
  alias_method_chain :clone_versioned_model, :associations

  def tag_summary
    tags.collect(&:name).sort.join(', ')
  end

  def property_summary
    properties_with_value.collect{|property| "#{property.name}: #{property.display_value}"}.sort
  end

  # optimization
  def project
    return Project.current
  end

  def history_events(pagination_options={})
    (self.versions_with_eager_loads_for_history_performance + self.revisions_in + self.card_copy_events).sort {|e1, e2| e2.updated_at <=> e1.updated_at }
  end

  def card_copy_events
    types = [CardCopyEvent::From, CardCopyEvent::To].map(&:name)
    Event.find(:all, :conditions => ["origin_id = ? and type in ( #{types.size.times.map{ "?" }.join(", ")} )", id, *types])
  end

  def revisions_in(period=nil)
    return [] unless self.project.has_source_repository?

    conditions = if period
      start_time, end_time = period.boundaries
      sql = [].tap do |result|
        result << " revisions.commit_time >= ? " if start_time
        result << " revisions.commit_time < ? " if end_time
      end.compact.join(' AND ')
      [sql, *[start_time, end_time].compact.collect(&:utc)]
    end
    self.revisions.find(:all, :conditions => conditions)
  end

  def assign_number
    self.number ||= project.next_card_number
  end

  def generate_changes(options = {})
    self.versions.each do |version|
      version.create_event unless version.event
    end
  end

  def properties_removed_as_not_applicable_to_card_type
    PropertyValueCollection.new(@properties_removed_as_not_applicable_to_card_type || [])
  end

  def set_default_description
    card_type.card_defaults.update_description(self)
  end

  def set_defaults(options = {})
    card_type.card_defaults.update_card(self, options)
  end

  def block_errors(error_messages)
    @blocked_errors ||= []
    @blocked_errors << error_messages
    @blocked_errors = @blocked_errors.flatten.uniq
  end

  def previous_version_or_nil
    self.versions.find(:first, :conditions => ["card_id = ? and version < ?", id, self.version], :order => 'version DESC')
  end
  memoize :previous_version_or_nil

  def clear_previous_version_or_nil
    clear_cached_results_for(:previous_version_or_nil)
  end

  def compute_aggregate_properties(options = {})
    each_aggregate_to_compute(options) do |card, aggregate_def|
      aggregate_def.compute_aggregate(card)
    end
  end

  def each_aggregate_to_compute(options = {}, &block)
    trees = options[:for_trees] || self.tree_configurations
    trees.compact.each do |tree|
      if tree.include_card?(self)
        each_aggregate_to_compute_for_tree(tree) do |card, aggregate_def|
          yield(card, aggregate_def)
        end
      end
    end
  end

  def grouped_properties_with_value
    if properties_with_value.empty?
      [OpenStruct.new(:name => nil, :properties => [])]
    else
      groups = properties_with_value.group_by(&:tree_name).inject([]) do |memo, pair|
        memo << OpenStruct.new(:name => pair.first, :properties => pair.last)
      end
      groups.smart_sort_by(&:name)
    end
  end

  def usages_as_plv
    return [] if new_record?
    project.project_variables.select { |plv| plv.uses_card?(self) }
  end

  def contain_hidden_properties?
    property_definitions_without_tree.select(&:hidden?).any?
  end

  def register_remove_card_after_save_callback_without_creating_new_version(tree_configuration)
    register_after_save_callback { tree_configuration.remove_card(self, nil, :change_version => latest_version_object.version) }
  end

  def stale_property?(property_definition)
    return false if new_record?
    unless @stale_property_definition_ids
      stale_property_definition_ids = Card.connection.select_values "SELECT DISTINCT prop_def_id FROM stale_prop_defs WHERE project_id = #{project.id} AND card_id = #{id}"
      @stale_property_definition_ids = stale_property_definition_ids.map(&:to_i)
    end
    @stale_property_definition_ids.include?(property_definition.id)
  end

  def latest_version_object
    if versions.loaded?
      versions.inject { |max_version, version| version.version > max_version.version ? version : max_version }
    else
      versions.find(:last)
    end
  end

  def as_value_for_property_defnition_condition(property_definition)
    return unless PropertyType::CardType === property_definition.property_type
    "(#{Card.quoted_table_name}.#{property_definition.column_name} = #{id})"
  end

  def copiable_projects
    writable_projects = if User.current.admin?
      Project.not_hidden.not_template
    else
      User.current.projects.not_hidden.not_template.reject { |p| p.readonly_member?(User.current) }
    end
    writable_projects.select { |p| p.card_types.find(:all, :conditions => ["LOWER(card_types.name) = ?", card_type.name.downcase]).any? }.smart_sort_by(&:name)
  end

  def copier(target_project)
    CardCopier.new(self, target_project)
  end

  def chart_executing_option
    {
      :controller => 'cards',
      :action => 'chart',
      :id => self.id
    }
  end

  def daily_history_chart_url(view_helper, params)
    view_helper.daily_history_chart_for_card_url(params.merge(:id => id))
  end

  def html_id
    "card_#{number}"
  end

  def without_transition_only_validation
    @valid_for_updating_transition_only_property = true
    yield
  ensure
    @valid_for_updating_transition_only_property = false
  end

  def invalid_for_updating_transition_only_property?
    !(new_record? || @valid_for_updating_transition_only_property)
  end

  def participants
    properties_with_value.select do |property_value|
      property_value.property_type.to_sym == :user
    end
  end

  def completed_checklist_items
    checklist_items.select(&:completed)
  end

  def incomplete_checklist_items
    checklist_items.select { |item| item.completed.blank? }
  end

  def add_checklist_items(checklist_items_hash)
    checklist_items_hash.each do |checklist_items_type, checklist_items|
      is_completed_item = checklist_items_type == CardImport::Mappings::COMPLETED_CHECKLIST_ITEMS

      self.checklist_items += checklist_items.each_with_index.map do |item_text, index|
        CardChecklistItem.new({:text => item_text,
                               :project_id => project.id,
                               :completed => is_completed_item,
                               :position => index
                          })
      end
    end
  end

  protected

  def generate_id
    self.id = Sequence.find('card_id_sequence').next
  end

  def set_not_applicable_properties_to_nil
    @properties_removed_as_not_applicable_to_card_type = []
    project.property_defintions_not_applicable_to_type(self.card_type_name).each do |na_prop_def|
      old_property = property_value(na_prop_def)
      na_prop_def.remove_value(self)
      @properties_removed_as_not_applicable_to_card_type << old_property if old_property.set?
    end
  end

  def create_card_deletion_version
    deletion_version = versions.create!(
          :project_id => project.id,
          :number => self.number,
          :version => next_version,
          :card_type_name => card_type_name,
          :name => name,
          :created_at => created_at,
          :updated_at => updated_at,
          :created_by_user_id => User.current.id,
          :modified_by_user_id => User.current.id
    )
  end

  def recompute_aggregate_if_card_type_changed
    return unless card_type_name_changed?
    card_and_agg_prop_defs = []
    each_aggregate_to_compute do |card, aggregate_def|
      card_and_agg_prop_defs << [card, aggregate_def]
    end

    card_and_agg_prop_defs.each do |card, aggregate_def|
      aggregate_def.compute_aggregate(card)
    end
  end

  def normalize_card_type_name
    self.write_attribute(:card_type_name, self.card_type.name)
  end


  def do_card_type_validation
    return unless card_type_name_changed?
    unless project.find_card_type_or_nil(self.card_type_name)
     self.errors.add_to_base("Card type #{self.card_type_name} does not exist in project #{self.project.name}.")
    end
  end

  def do_plv_usage_checking_on_card_type_change
    return if !card_type_name_changed? || (usages = usages_as_plv).empty?

    usages_listing = usages.collect { |plv| plv.display_name.bold }.join(', ')
    self.errors.add_to_base("Cannot change card type because card is being used as the value of #{'project variable'.plural(usages.size)}: #{usages_listing}")
  end

  def do_transition_usage_checking_on_card_type_change
    return if !card_type_name_changed?
    old_card_type_name = card_type_name_change.first
    return if (usages = usages_as_tree_relationship_property_in_transitions(old_card_type_name)).empty?
    usages_listing = usages.collect { |t| t.name.bold }.sort.join(', ')
    self.errors.add_to_base("Cannot change card type because card is being used in #{'transition'.plural(usages.size)}: #{usages_listing}")
  end

  def do_validate_not_applicable_properties
    return unless validate_not_applicable_properties?
    return if @updating_prop_names.blank?

    project.property_defintions_not_applicable_to_type(self.card_type_name).each do |na_prop_def|
      if @updating_prop_names.include?(na_prop_def.name.downcase)
        self.errors.add_to_base "#{na_prop_def.name} is not being applicable to card type #{card_type_name}"
      end
    end
  end

  def do_validate_updating_properties_existing
    return if @updating_prop_names.blank?

    prop_names = project.property_definitions_with_hidden.collect(&:name).collect(&:downcase) + ['type']
    @updating_prop_names.each do |prop_name|
      prop_name = MingleUpgradeHelper.fix_string_encoding_19(prop_name) if MingleUpgradeHelper.ruby_1_9?
      unless prop_names.include?(prop_name.to_s.downcase)
        self.errors.add_to_base "Project #{project.name} does not have card property #{prop_name.bold}"
      end
    end
  end

  def convert_tab_character_to_space_in_description
    description.gsub!(/\t/, ' ') if description
  end

  private

  def favorites_using_card(favorites)
    favorites.include_favorited.collect(&:favorited).select { |fav| CardListView === fav && fav.uses_card?(self) }
  end

  def compute_formulas
    formula_property_definitions = property_definitions_with_hidden.find_all {|prop_def| prop_def.is_a?(FormulaPropertyDefinition)}
    formula_property_definitions.each do |prop_def|
      prop_def.update_card_formula(self)
    end
  end

  def compute_aggregate_properties_on_property_change
    latest_version = self
    previous_version = previous_version_or_nil

    if previous_version
      associated_property_definitions_changed = project.aggregate_associated_property_definitions.any? { |pd| pd.different?(latest_version, previous_version) }
      relationship_changed = project.relationship_property_definitions.any? { |pd| pd.different?(latest_version, previous_version) }
      taggings_changed = latest_version.tags != previous_version.tags
      return unless relationship_changed || associated_property_definitions_changed || taggings_changed
    end

    compute_aggregate_properties
  end

  def self.bind_variables(sql_and_variables)
    Card.send(:sanitize_sql, sql_and_variables)
  end

  def self.sql_from_options(options)
    Card.send(:construct_finder_sql, options)
  end

  def remove_blocked_errors
    return if @blocked_errors.blank?
    full_messages = []
    self.errors.full_messages.each do |error_message|
      full_messages << error_message unless @blocked_errors.include?(error_message)
    end
    self.errors.clear
    full_messages.each { |msg| self.errors.add_to_base(msg) }
  end

end

class Card::Version < ActiveRecord::Base
  include Card::CardVersionAttributeMethods
  extend Card::ThreadSafe::CardVersionTableName
  extend Card::ThreadSafe::Columns
  include CardTreeMethods
  include Renderable

  belongs_to :project, :class_name => '::Project', :foreign_key => 'project_id'

  belongs_to :created_by, :class_name => '::User', :foreign_key => 'created_by_user_id'
  belongs_to :modified_by, :class_name => '::User', :foreign_key => 'modified_by_user_id'
  has_one :event, :as => :origin, :class_name => '::CardVersionEvent'
  before_create :generate_id

  v1_serializes_as :complete => [:api_attributes],
                   :element_name => 'card'

  v2_serializes_as :complete => [:name, :description, :card_type, :id, :number, :project, :version, :created_on, :modified_on, :modified_by, :created_by, :properties, :rendered_description],
                   :compact => [:number],
                   :element_name => 'card'

  compact_at_level 0

  self.resource_link_route_options = proc {|version| { :number => version.number, :version => version.version } }
  self.routing_name = "card"

  def versioned
    card
  end

  acts_as_taggable
  acts_as_attachable

  after_create :create_event

  include CardMethods
  include CardJson

  def card_type_with_handling_deleted_types
    card_type_without_handling_deleted_types || DeletedCardType.new(self.card_type_name)
  end

  alias_method_chain :card_type, :handling_deleted_types

  NULL = Null.instance(:tags => [], :attachments => [])

  class << self
    def load_history_event(project, ids)
      ([]).tap do |result|
        ids.each_slice(ORACLE_BATCH_LIMIT) do |chunk_of_ids|
          result << all(:include => [:modified_by, :card, :event, {:taggings => :tag, :attachings => :attachment, :event => :changes}],
            :conditions => ["#{self.quoted_table_name}.project_id = ? and #{self.quoted_table_name}.id in (#{chunk_of_ids.join(',')})", project.id])
        end
      end
    end
  end

  def resource_link_title
    "#{type_and_number} (v#{version})"
  end

  def first_version
    self.class.minimum(:version, :conditions => ['card_id = ?', self.card_id])
  end

  def first?
    version == first_version
  end

  # (perf) pls don't use the 'card' association in this method (gen changes background job will get slow)
  def previous
    self.class.find(:first, :conditions => ["card_id = ? AND version < ?", self.card_id, version], :order => 'version DESC')
  end

  def card_include_deleted
    project.cards.find_existing_or_deleted_card(self.card_id)
  end

  def compute_aggregate_requests
    nil
  end

  def event_type
    :card_version
  end

  def latest_version?
    self.version == latest_version
  end

  def latest_version
    self.class.find(:first, :conditions => ["card_id = ?", self.card_id], :order => 'version DESC').version
  end

  def successor_to?(event)
    self.event_type == event.event_type and #same kind of event
    self.version - 1 == event.version and #one version ago
    self.card_id == event.card_id #on the same reference object
  end

  def system_generated?
    system_generated_comment
  end

  def changes
    card_type = project.find_card_type_or_nil(self.card_type_name)
    return event_changes unless card_type
    return [] unless event
    event.changes_for_card_type(card_type)
  end

  def event_changes
    event ? event.changes : []
  end

  def tag_additions
    changes.collect(&:added_tag).compact
  end

  def comment_details
    Card::Comment.new(self, :content => comment)
  end

  def property_changes
    changes.select { |change| project.property_definitions.any? { |definition| change.field == definition.name } }
  end

  def describe_changes
    changes.collect(&:describe).compact
  end

  def create_event
    Event.with_project_scope(project.id, self.updated_at, self.modified_by_user_id) do
      project.cards.exists?(card_id) ? Event.card_version(self) : Event.card_deletion(self)
    end
  end

  def details_still_loading?
    (event || create_event && self.reload.event).details_still_loading?
  end

  # optimization
  def project
    return Project.current
  end

  def stale_property?(property_definition)
    false
  end

  def chart_executing_option
    {
      :controller => 'cards',
      :action => 'chart',
      :id => self.card_id,
      :version => self.version
    }
  end

  def daily_history_chart_url(view_helper, params)
    return versioned.daily_history_chart_url(view_helper, params) if latest_version?
    view_helper.daily_history_chart_for_unsupported_url({:position => params[:position], :unsupported_content_provider => 'a card version'})
  end

  def card_resource_link
    Card.resource_link(type_and_number, :number => number)
    opts = {:number => number}
    if group_by_card_id_with(self.number).size > 1
      opts.merge!(:id => self.card_id)
    end
    Card.resource_link(type_and_number, opts)
  end

  protected
  def group_by_card_id_with(card_number)
    self.class.count(:conditions => ["#{Project.connection.quote_column_name('number')} = ?", card_number], :group => :card_id)
  end

  def generate_id
    self.id = Sequence.find('card_version_id_sequence').next
  end
end
