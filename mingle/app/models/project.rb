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

class Project < Deliverable
  #todo: replace no such prop runtime error and Column::PropertyNotExistError with this error
  class NoSuchPropertyError < StandardError
  end

  MAX_NUMBER = 2147483647 # Postgresql: integer 4 bytes usual choice for integer -2147483648 to +2147483647
# Mysql: BIGINT  int(8)  -9223372036854775808 9223372036854775807, the rails integer type in the mysql is int(10)
  IDENTIFIER_MAX_LENGTH = 30
  ALLOWED_CHARACTERS_IN_IDENTIFIER = /[^a-zA-Z0-9]/

  DEFAULT_PRECISION = 2
  CARD_MATCHING_PATTERN = ''
  OVERVIEW_PAGE_IDENTIFIER = 'Overview_Page'
  AVAILABLE_DATE_FORMATS = [
  ["dd mmm yyyy", Date::DAY_LONG_MONTH_YEAR],
  ["dd/mm/yyyy", Date::DAY_MONTH_YEAR],
  ["mm/dd/yyyy", Date::MONTH_DAY_YEAR],
  ["yyyy/mm/dd", Date::YEAR_MONTH_DAY]]

  INTERNAL_TABLE_PREFIX_PATTERN = /^mi_\d{6}/

  RESERVED_IDENTIFIERS = [PropertyValue::IGNORED_IDENTIFIER, PropertyValue::ANY, PropertyType::UserType::CURRENT_USER, PropertyType::DateType::PROJECT_TODAY,
                          PropertyType::DateType::TODAY, Transition::USER_INPUT_REQUIRED, Transition::USER_INPUT_OPTIONAL, PropertyValue::NOT_SET, PropertyValue::SET, PropertyValue::NO_CHANGE]

  RESERVED_VALUE_IDENTIFER_REGEX = /^\s*\(.*\)\s*$/

  include Identifiable
  include Messaging::MessageProvider
  include Activation
  include CardIdConvertion
  include HasManyCardListViews
  include AutoEnrollUserType::ProjectExt
  include FavoritesAndTabs
  include CorruptionChecking
  include Accessiblity
  include AdminJobs
  include HasManyRenderables
  include MyWorkProjectSupport
  include YamlExportSupport

  before_destroy :cascade_all_children

  def cascade_all_children
    ProjectDelete.new(self).execute
  end

  if MingleConfiguration.public_icons?
    file_column :icon, :root_path => DataDir::Public.directory.pathname, :fix_file_extensions => false, :bucket_name => MingleConfiguration.icons_bucket_name, :public => true
  else
    file_column :icon, :root_path => DataDir::Public.directory.pathname, :fix_file_extensions => false
  end

  has_many :cards
  remove_reflection_table_name_cache(:cards)

  has_many :card_types, :order => "#{ActiveRecord::Base.table_name_prefix}card_types.position", :include => :property_type_mappings, :after_add => :remove_duplicate_card_types
  has_many :card_versions, :class_name => 'Card::Version'
  remove_reflection_table_name_cache(:card_versions)

  has_many :pages
  has_many :page_versions, :class_name => 'Page::Version', :foreign_key => 'project_id'
  has_many :tags

  has_many :raised_dependencies, :class_name => "Dependency", :foreign_key => :raising_project_id
  has_many :resolving_dependencies, :class_name => "Dependency", :foreign_key => :resolving_project_id

  has_many :murmurs
  has_many :conversations
  #do not eager load actions. It adds a severe performance cost
  has_many :transitions, :order => "LOWER(#{ActiveRecord::Base.table_name_prefix}transitions.name)", :include => [:actions, {:prerequisites => :property_definition}]

  has_many :all_property_definitions, :class_name => 'PropertyDefinition', :include => [:property_type_mappings, :project_variables], :order => "#{ActiveRecord::Base.table_name_prefix}property_definitions.name" do
    def select_in_order(ids)
      ids.map { |pd_id| proxy_target.detect { |pd| pd.id.to_s == pd_id.to_s }   }
    end
  end
  has_many :property_definitions_with_hidden_for_migration, :class_name => 'PropertyDefinition', :order => "#{ActiveRecord::Base.table_name_prefix}property_definitions.name"

  alias_method :property_definitions_with_hidden, :all_property_definitions

  has_many :dependency_views
  named_scope :all_selected, lambda { |identifiers| {:conditions => ["identifier IN (?) ", identifiers]}  }


  def t(table_name)
    ActiveRecord::Base.connection.safe_table_name(table_name)
  end

  def c(column_name)
    ActiveRecord::Base.connection.quote_column_name(column_name)
  end

  self.resource_link_route_options = proc {|project| { :project_id => project.identifier } }

  def dependencies
    Dependency.all_for self
  end

  def new_waiting_resolving_count
    self.resolving_dependencies.count(:conditions => ["status = ?", Dependency::NEW])
  end

  def last_event_id
    Event.maximum(:id, :conditions => ["deliverable_id = ?", id])
  end

  def property_definitions
    all_property_definitions.reject(&:hidden?)
  end
  memoize :property_definitions

  def all_numeric_property_definitions
    all_property_definitions.select { |pd| pd.numeric? && !pd.hidden? }
  end

  def numeric_list_property_definitions_with_hidden
    enum_property_definitions_with_hidden.select(&:is_numeric?)
  end

  def numeric_free_property_definitions_with_hidden
    text_property_definitions_with_hidden.select(&:is_numeric?)
  end

  def text_property_definitions_with_hidden
    select_property_definitions_of_type TextPropertyDefinition
  end

  def enum_property_definitions_with_hidden
    select_property_definitions_of_type EnumeratedPropertyDefinition
  end

  def user_property_definitions_with_hidden
    select_property_definitions_of_type UserPropertyDefinition
  end

  def date_property_definitions_with_hidden
    select_property_definitions_of_type DatePropertyDefinition
  end

  def aggregate_property_definitions_with_hidden
    select_property_definitions_of_type AggregatePropertyDefinition
  end

  def card_relationship_property_definitions
    select_property_definitions_of_type CardRelationshipPropertyDefinition, :include_hidden => false
  end

  def card_relationship_property_definitions_with_hidden
    select_property_definitions_of_type CardRelationshipPropertyDefinition
  end

  def relationship_property_definitions
    select_property_definitions_of_type TreeRelationshipPropertyDefinition
  end

  def formula_property_definitions_with_hidden
    all_property_definitions.inject(FormulaPropertyDefinition::ArrayExt.new) do |result, pd|
      result << pd if pd.class == FormulaPropertyDefinition
      result
    end
  end

  has_many :attachments
  has_many :revisions, :order => 'commit_time ASC'
  has_many :card_revision_links
  has_many :card_murmur_links
  has_many :history_subscriptions
  has_many :history_subscribers, :through => :history_subscriptions, :source => :user, :uniq => true
  has_many :card_imports
  has_many :card_importing_previews
  has_many :project_exports
  has_many :program_projects
  has_many :programs, :through => :program_projects
  has_many :card_defaults, :class_name => 'CardDefaults'

  has_many :tree_configurations
  has_many :project_variables
  has_one :cache_key_DO_NOT_REFERENCE, :class_name => 'CacheKey', :foreign_key => 'deliverable_id'
  has_many :events, :order => 'mingle_timestamp, id ASC', :include => [:origin, :created_by, :changes ], :foreign_key => 'deliverable_id'
  has_many :events_without_eager_loading, :class_name => '::Event', :order => 'id ASC', :foreign_key => 'deliverable_id'

  acts_as_traceable { User.current }

  after_create :create_card_schema, :create_card_number_sequence, :create_first_card_type_if_there_is_none
  before_create :generate_secret_key_if_no_one, :set_cards_table_and_card_versions_table
  before_save :set_hidden_to_true_if_it_is_nil
  before_validation :strip_whitespace_and_underscores_from_start_and_end
  before_update :update_card_schema_names

  validate :validate_conflicts_with_mingle_internal_prefix,
           :validate_precision
  validates_associated :card_keywords, :message => CardKeywords::DEFAULT_INVALID_MESSAGE
  validates_email_format_of :email_address, :allow_blank => true

  validates_file_format_of_with_custom_message :icon, :in => %w(gif png jpg jpeg bmp tiff).upcase_dup, :error_message => 'is an invalid format. Supported formats are BMP, GIF, JPEG and PNG.'

  validate_filesize_of_with_custom_message :icon, :in => 0..2.megabytes, :size_bigger_warn => "is larger than the allowed file size. Maximum file size is 2 MB."

  strip_on_write :except => [:name]

  attr_reader :secret_key_changed

  validates_length_of [:name, :time_zone, :secret_key, :email_address, :email_sender_name, :date_format, :auto_enroll_user_type, :cards_table, :card_versions_table], :maximum => 255, :allow_blank => true

  validates_uniqueness_of :name, :case_sensitive => false

  skip_has_many_association_validations

  named_scope :not_hidden,   :conditions => { :hidden => false }
  named_scope :not_template, :conditions => [ "template = ? OR template IS NULL", false ]
  named_scope :anonymous_accessible, :conditions => [ "anonymous_accessible = ?", true ]
  named_scope :having_repository, lambda { {:conditions => [" id IN (?) ", MinglePlugins::Source.project_ids_with_configurations.tap{|project_ids| project_ids.blank? ? "''" :  project_ids } ]} }
  named_scope :order_by_name, :order => 'lower(name)'

  def self.all_available
    not_hidden.not_template
  end

  attr_accessor :project_cache_key

  def self.card_type_definition
    CardTypeDefinition::INSTANCE
  end

  def self.id_to_identifier(project_id)
    connection.select_value(SqlHelper.sanitize_sql(
      "SELECT identifier FROM #{Project.quoted_table_name} WHERE id = ?", project_id))
  end

  def cache_key
    return self.cache_key_DO_NOT_REFERENCE if self.cache_key_DO_NOT_REFERENCE
    key = CacheKey.create(:deliverable => self)
    key.touch_structure_key
    key.touch_card_key
    self.cache_key_DO_NOT_REFERENCE = key
  end

  def to_num(number)
    number.to_s.to_num(precision)
  end

  def compare_numbers(number_1, number_2)
    # Use BigDecimal because the float is inherent inaccuracy
    BigDecimal.new(to_num(number_1).to_s)  == BigDecimal.new(to_num(number_2).to_s)
  end

  def format_num(number)
    format "%0.#{precision}f", number
  end

  def format_number(number_str)
    precisioned_value = to_num(number_str.to_f)
    is_out_of_precision =  BigDecimal.new(precisioned_value.to_s) != BigDecimal.new(number_str)
    if !is_out_of_precision && number_str.index('.')
      number_precision =  number_str.length - number_str.index('.') - 1
      is_out_of_precision = number_precision > precision
    end
    is_out_of_precision ? format_num(precisioned_value) : number_str
  end

  # remove extra decimal places beyond project precision while maintaining any precision below that
  def to_num_maintain_precision(string)
    return if string.nil?
    string.to_num_maintain_precision(precision)
  end

  def format_time(time)
    time_format = "#{date_format} %H:%M %Z"
    time.in_time_zone(time_zone).strftime(time_format)
  end

  def format_date(date)
    date.strftime(date_format)
  end

  def format_time_without_date(time)
    time.in_time_zone(time_zone).strftime('%H:%M %Z')
  end

  def local_to_utc(time)
    self.time_zone_obj.local_to_utc(time)
  end

  def card_type_definition
    CardTypeDefinition.new(self)
  end

  def tree_belonging_property_definitions
    tree_configurations.collect{ |config| TreeBelongingPropertyDefinition.new(config) }
  end

  def text_list_property_definitions_with_hidden
    enum_property_definitions_with_hidden.reject(&:is_numeric?)
  end

  def text_free_property_definitions_with_hidden
    text_property_definitions_with_hidden.reject(&:is_numeric?)
  end

  def property_definitions_in_smart_order(inluding_hidden=false)
    (inluding_hidden ? property_definitions_with_hidden : property_definitions).smart_sort_by(&:name)
  end

  def property_definitions_without_relationship
    property_definitions_with_hidden.reject{|pd| pd.class == TreeRelationshipPropertyDefinition}.smart_sort_by(&:name)
  end

  def managable_property_definitions
    property_definitions_in_smart_order(false).select(&:managable?)
  end

  def managable_property_definitions_with_hidden()
    property_definitions_in_smart_order(true).select(&:managable?)
  end

  def property_definitions_for_filter(card_type_name=nil)
    property_definitions_of_card_type(card_type_name).select(&:finite_valued?)
  end

  def property_definitions_for_columns(card_type_name=nil)
    property_definitions_of_card_type(card_type_name) + [find_property_definition('created_by'), find_property_definition('modified_by')]
  end
  memoize :property_definitions_for_columns

  def property_definitions_including_type(options = {:include_hidden => false})
    all_without_type = options[:include_hidden] ? property_definitions_with_hidden : property_definitions
    all_without_type + [card_type_definition]
  end

  def property_definitions_of_card_type(card_type = nil)
    card_type = card_type && project.card_types.detect { |type| type.name.downcase == card_type.downcase } unless card_type.respond_to?(:property_definitions)
    pds_in_db = card_type ? card_type.property_definitions : property_definitions.select(&:global?)
    pds_in_db.smart_sort_by(&:name).unshift card_type_definition
  end

  def property_defintions_not_applicable_to_type(card_type_name)
    card_type_name = card_type_name.downcase
    card_type = self.card_types.detect{ |ct| ct.name.downcase.trim == card_type_name.downcase.trim }
    prop_defs_without_hidden = card_type ? card_type.property_definitions_with_hidden_without_order : [] # leave this outside of the following loop for better performance
    self.property_definitions_with_hidden.reject do |prop_def|
      prop_defs_without_hidden.any? { |type_prop_def| type_prop_def == prop_def }
    end
  end

  def self.admins_list
    connection.execute(SqlHelper.sanitize_sql("SELECT  #{connection.quote_column_name('deliverables.name')} AS project_name, #{connection.quote_column_name('users.name')} AS admin_name, #{connection.quote_column_name('users.email')}
                         FROM #{connection.quote_table_name('member_roles')}
                         INNER JOIN #{connection.quote_table_name('users')} ON #{connection.quote_column_name('users.id')} = #{connection.quote_column_name('member_roles.member_id')}
                         INNER JOIN #{connection.quote_table_name('deliverables')} ON #{connection.quote_column_name('member_roles.deliverable_id')} = #{connection.quote_column_name('deliverables.id')}
                         WHERE #{connection.quote_column_name('member_roles.permission')} = ? ORDER BY #{connection.quote_column_name('deliverables.name')}", 'project_admin'))
  end

  def property_definitions_without_tree
    property_definitions.reject(&:tree_special?)
  end

  def calculated_property_definitions_with_hidden
    aggregate_property_definitions_with_hidden + formula_property_definitions_with_hidden
  end

  alias_method :available_tree_configurations, :tree_configurations

  def hidden_property_definitions
    property_definitions_with_hidden.select(&:hidden)
  end

  def date_format=(new_format)
    card_list_views.each do |view|
      view.update_date_format(self.date_format, new_format)
      view.save!
    end
    write_attribute(:date_format, new_format)
  end

  def precision=(new_precision)
    if record_exists? && new_precision.to_i != precision.to_i
      PrecisionChange.create_change(self, precision.to_i, new_precision.to_i).run
    end
    write_attribute(:precision, new_precision)
  end

  def merge_template(template, options={})
    exported_template = DeliverableImportExport::ProjectExporter.export_with_error_raised(:project => template, :template => true)
    merge_template_from_file(exported_template, options)
    FileUtils.rm_rf(exported_template)
  end

  def merge_template_from_file(template_file, options={})
    card_types.each(&:destroy)
    request = User.current.asynch_requests.create_project_export_asynch_request(self.identifier)
    import = DeliverableImportExport::ProjectImporter.for_synchronous_import_into_existing_project(self, template_file, request)
    import.import options.merge(:reset_timestamps => true)
  end

  def next_likely_number
    self.cards.highest_card_number.to_i + 1
  end

  def next_card_number
    Sequence.find_table_sequence(card_number_sequence_name).next
  end

  def create_card_relationship_property_definition(options)
    authorize_property_definition_creation(options)
    self.all_property_definitions.create_card_relationship_property_definition(options)
  end

  def create_text_list_definition(options)
    authorize_property_definition_creation(options)
    self.all_property_definitions.create_text_list_property_definition(options)
  end

  def create_text_definition(options)
    authorize_property_definition_creation(options)
    self.all_property_definitions.create_any_text_property_definition(options)
  end

  def create_date_definition(options)
    authorize_property_definition_creation(options)
    self.all_property_definitions.create_date_property_definition(options)
  end

  def create_numeric_free_property_definition(options)
    authorize_property_definition_creation(options)
    self.all_property_definitions.create_any_number_property_definition(options)
  end

  def create_numeric_list_property_definition(options)
    authorize_property_definition_creation(options)
    self.all_property_definitions.create_number_list_property_definition(options)
  end

  def export_csv_cards(view, include_description=false, include_all_columns=true)
    CardExport.new(self, view).export(include_description, include_all_columns)
  end

  def has_source_repository?
    repository_configuration != nil
  end

  def can_connect_to_source_repository?
    has_source_repository? && repository_configuration.can_connect?
  end

  def source_repository_empty?
    repository_configuration.repository_empty?
  end

  def delete_repository_configuration
    self.errors.add_to_base(__config.errors.full_messages) unless repository_configuration.mark_for_deletion
    clear_cached_results_for(:repository_configuration)
  end

  def source_repository_path
    repository_configuration.repository_path
  end

  def repository_revision(revision_identifier)
    repository_configuration.repository.revision(revision_identifier)
  end

  def repository_node(path, revision_identifier)
    repository_configuration.repository.node(path, revision_identifier)
  end

  def repository_vocabulary
    repository_configuration.vocabulary
  end

  def repository_name
    repository_configuration.display_name
  end

  def revisions_for_card_number(card_number)
    revisions = self.revisions.select { |revision| card_keywords.included_in?(revision.commit_message, card_number) }
    revisions.sort { |rev_left, rev_right| rev_right.number <=> rev_left.number }
  end

  def has_revisions?
    Revision.count(:conditions => {:project_id => self.project.id}) > 0
  end

  def youngest_revision
    revisions.find(:first, :order => "#{connection.quote_column_name('number')} desc")
  end

  def cache_revisions(batch_size = 100)
    return unless has_source_repository?
    return unless FEATURES.active?("scm")
    RevisionsHeaderCaching.new(repository_configuration).cache_revisions(batch_size)
  end

  def re_initialize_revisions_cache
    return unless has_source_repository?
    repository_configuration.re_initialize!
  end

  def source_repository_initialized?
    repository_configuration.initialized?
  end

  delegate :source_browsable?, :to => :repository_configuration
  delegate :source_browsing_ready?, :to => :repository_configuration


  def overview_page_identifier
    OVERVIEW_PAGE_IDENTIFIER
  end

  def overview_page
    @overview_page ||= pages.find_by_identifier(overview_page_identifier)
  end

  def valid_tags?(tag_names)
    existing_tag_names = tags.collect { |tag| tag.name.downcase }
    Tag.parse(tag_names).all? { |tag_name|  existing_tag_names.include?(tag_name) }
  end

  def tag_named(tag_or_name)
    tag_or_name = tags.select { |tag| tag.name.downcase == tag_or_name.downcase }.first unless tag_or_name.respond_to? :name
    tag_or_name
  end

  def project
# the project of a project is the project itself
# for example the macro system asks a "content_provider" what project it belongs to
# so every object in the system needs to be able to answer that question including a project
    self
  end

  def header_actions_page
    pages.find_by_name('Special:HeaderActions')
  end
  memoize :header_actions_page

  def revision_regexp(number='\d+')
    card_keywords.keywords_regexp(number)
  end

  def keywords_regexp_string
    card_keywords.keywords_regexp_string
  end

  def with_lock
# TODO not implemented yet
    yield
  end

  def card_schema
    CardSchema.new(self)
  end

  def update_card_schema_names
    with_lock do
      card_schema.update_names
    end
  end

  def set_cards_table_and_card_versions_table
    if self.identifier_changed?
      self.cards_table = ActiveRecord::Base.connection.safe_table_name(CardSchema.generate_cards_table_name(self.identifier))
      self.card_versions_table = ActiveRecord::Base.connection.safe_table_name(CardSchema.generate_card_versions_table_name(self.identifier))
    end
  end

  def update_card_schema
    with_lock do
      activate
      card_schema.update
    end
  end

  def create_card_schema
    with_lock do
      activate
      card_schema.create
    end
  end

  def drop_card_schema
    activate
    card_schema.drop
  end

  def last_activity
    last_activity_of_card = card_versions.maximum(:updated_at) rescue nil
    [last_activity_of_card, page_versions.maximum(:updated_at)].compact.max
  end

  def find_card_type(card_type_name)
    return if card_type_name.blank?
    card_type = find_card_type_or_nil(card_type_name)
    raise "No card type found with name #{card_type_name.bold}" if card_type.nil?
    card_type
  end

  def find_card_type_or_nil(card_type_name)
    return if card_type_name.blank?
    self.card_types.detect { |ct| ct.name.downcase.trim == card_type_name.to_s.downcase.trim }
  end

  def find_card_type_by_id(id)
    return if id.blank?
    card_type = self.card_types.detect { |ct| ct.id == id }
    raise "No card type found with id #{id}, current card_types: #{card_types.collect(&:name).collect(&:bold).join(", ")}" if card_type.nil?
    card_type
  end

  def find_property_definition_or_nil(property_name, options={})
    return nil if property_name.nil?
    return property_name if property_name.kind_of?(PropertyDefinition)
    property_name = property_name.to_s
    return find_predefined_property_definition(property_name) if PropertyDefinition.predefined?(property_name)
    if tree_config = tree_configurations.detect{ |config| config.name.ignore_case_equal?(property_name) }
       return TreeBelongingPropertyDefinition.new(tree_config)
    end
    candidates = options[:with_hidden] ? property_definitions_with_hidden : property_definitions

    candidates.detect { |definition| definition.name.downcase == property_name.to_s.downcase.trim }
  end

  memoize :find_property_definition_or_nil

  # note: find_property_definition currently also includes card type def.  we use this method if we are certain that we want to
  # include card type def
  def find_property_definition_including_card_type_def(property_name, options = {})
    find_property_definition_or_nil(property_name, options)
  end

  def find_property_definition(property_name, options={})
    property = find_property_definition_or_nil(property_name, options)
    raise "No such property: #{property_name.to_s.bold}" unless property
    property
  end

  def find_property_definitions_by_card_types(card_types)
    card_types.collect { |card_type| property_definitions_of_card_type(card_type) }.flatten.uniq
  end

  def find_property_definition_by_ruby_name(ruby_name)
    return nil if ruby_name.nil?
    property_definitions_with_hidden.find_by_ruby_name(ruby_name)
  end

  def find_predefined_property_definition(property_name)
    property_name = property_name.downcase
    @predefined_prop_defs ||= {}
    @predefined_prop_defs[property_name] ||= PredefinedPropertyDefinitions.find(self, property_name)
  end

  def predefined_property_definitions
    PredefinedPropertyDefinitions::TYPES.keys.map do |property_name|
      self.find_predefined_property_definition(property_name)
    end
  end

  def association_property_definitions
    property_definitions.select { |prop_def| prop_def.is_a?(AssociationPropertyDefinition) }
  end

  def find_tree_configuration(name)
    tree_configurations.detect { |config| config.name.ignore_case_equal?(name) }
  end

  def property_value(property_definition_name, value_identifier)
    prop_def = find_property_definition(property_definition_name, :with_hidden => true)
    PropertyValue.create_from_db_identifier(prop_def, value_identifier)
  end

  def find_enumeration_value(property_or_id, value = nil, options={:with_hidden => false})
    if value
      find_property_definition(property_or_id, options).enumeration_values.detect{ |ev| ev.value.downcase == value.downcase }
    else
      enumeration_value = EnumerationValue.find(property_or_id)
      if enumeration_value.property_definition.nil? || enumeration_value.property_definition.project_id != self.id
        raise ActiveRecord::RecordNotFound, "EnumerationValue with id #{property_or_id.bold} not found in Project #{self.id.bold}"
      end
      enumeration_value
    end
  end

# allows optimization -- each of my EnumeratedPropertyDefintion does not hit DB to find values
  def find_enumeration_values(enumerated_property_defintion)
    find_all_enumeration_values[enumerated_property_defintion.id] || []
  end

  def find_all_enumeration_values
    all_pd_ids = property_definitions_with_hidden.collect(&:id)
    return {} if all_pd_ids.empty?
    values = EnumerationValue.find(:all, :conditions => "property_definition_id IN (#{all_pd_ids.join(',')})", :order => 'position')
    values.group_by(&:property_definition_id)
  end
  memoize :find_all_enumeration_values

  def clear_enumeration_values_cache
    clear_cached_results_for(:find_all_enumeration_values)
  end

  def reload_with_clearing_cache(options = {})
    clear_enumeration_values_cache
    clear_cached_results_for(:repository_configuration)
    clear_cached_results_for(:property_definitions)
    clear_cached_results_for(:property_definitions_for_columns)
    clear_cached_results_for(:find_property_definition_or_nil)
    clear_cached_results_for(:user_defined_tab_favorites)
    reload_without_clearing_cache(options)
  end

  alias_method_chain :reload, :clearing_cache

  def generate_secret_key
    self.secret_key = (0..56).collect { SecureRandomHelper.random_byte }.pack('c56').to_base64_url_safe
    @secret_key_changed = true
  end

  def generate_secret_key!
    if id && has_source_repository?
      plain_repository_password = repository_configuration.password
    end
    generate_secret_key
    save_with_validation(false)
    update_repository_configuration_password(plain_repository_password)
  end

  def update_repository_configuration_password(plain_repository_password)
    if id && has_source_repository?
      repository_configuration.reload_plugin
      repository_configuration.password = plain_repository_password unless plain_repository_password.blank?
      repository_configuration.save!
    end
  end

  def encrypt(secret_stuff)
    generate_secret_key! unless secret_key
    secret_stuff = "MAGIC:#{secret_stuff}"
    encrypted_java_bytes = MingleCipher.new(secret_key.from_base64_url_safe).encrypt(secret_stuff)
    bytes = String.from_java_bytes(encrypted_java_bytes)
    final = bytes.to_base64_url_safe
    final
  end

  class DecryptionError < StandardError
  end

  def decrypt(encrypted)
    return nil if encrypted.nil?

    begin
      decrypted = MingleCipher.new(secret_key.from_base64_url_safe).decrypt(encrypted.from_base64_url_safe.to_java_bytes)
    rescue => err
      logger.debug("could not decrypt: #{encrypted}")
      logger.debug(err)
      raise DecryptionError.new("could not decrypt: #{encrypted}")
    end
    if decrypted =~ /^MAGIC:(.*)$/
      $1
    else
      logger.debug("decrypted string did not contain magic, it was: #{decrypted}")
      raise DecryptionError.new("decrypted string did not contain magic, it was: #{decrypted}")
    end
  end

  def valid_tag?(tag)
    tag_named(tag)
  end

  def card_keywords
    CardKeywords.new(self, @attributes["card_keywords"])
  end
  alias :keywords :card_keywords

  def card_keywords=(new_card_keywords)
    if read_attribute("card_keywords") != new_card_keywords
      rebuild_card_murmur_links if !self.new_record?
    end
    write_attribute("card_keywords", CardKeywords.new(self, new_card_keywords).value_for_save)
  end

  def card_prefixes_regexp
    card_keywords.card_prefixes_regexp
  end

  def update_full_text_index(options={})
    with_active_project do
      FullTextSearch::IndexingProjectsProcessor.request_indexing([self])
    end
  end

  def search_index_name
    Project.index_name.call(nil)
  end

  def self.index_name
    Proc.new { |searchable| ElasticSearch.index_name }
  end

  def delete_search_index
    ElasticSearch.deindex_for_project(id, search_index_name)
  end

  def self.rebuild_card_murmur_links
    Project.not_hidden.shift_each!(&:rebuild_card_murmur_links)
  end

  def rebuild_card_murmur_links
    Project.connection.execute("DELETE FROM #{ActiveRecord::Base.table_name_prefix}card_murmur_links WHERE project_id = #{self.id}")
    CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor.request_rebuild_links(self)
  end

  def email_sender
    %{#{self.email_sender_name}<#{self.email_address}>}
  end

  def skip_revision_notification?
    !(has_source_repository? && source_repository_initialized?)
  end

  def send_history_notifications
    self.with_active_project do
      self.history_subscribers.each do |user|
        user.send_history_notifications_for(self, :skip_revision_notification => self.skip_revision_notification?)
      end
    end
  end

  def create_history_subscription(user, filter_params)
    raise "Cannot create subscription for a user who is not a team member!" unless (member?(user) || user.admin?)
    subscription = history_subscriptions.new(:user => user, :filter_params => filter_params, :project => self)
    make_history_subscription_current(subscription)
    subscription.save
    subscription
  end

  def make_history_subscription_current(history_subscription)
    history_subscription.last_max_card_version_id = self.card_versions.maximum("id") || 0
    history_subscription.last_max_page_version_id = self.page_versions.maximum("id") || 0
    history_subscription.last_max_revision_id = self.revisions.maximum("id") || 0
  end

  def roll_ahead_history_subscriptions_to_youngest_revision
    highest_revision_id = Revision.maximum(:id, :conditions => {:project_id => self.id}).to_i
    history_subscriptions.update_last_max_revision_id_to(highest_revision_id, self.id)
  end

  def self.generate_changes
    Project.not_hidden.shift_each!(&:generate_changes)
  end

  def generate_changes
    HistoryGeneration.generate_changes(self)
  end

  def compute_aggregates
    aggregate_property_definitions_with_hidden.each(&:update_cards_across_project)
  end

  def reset_card_number_sequence_to(number)
    Sequence.find_table_sequence(card_number_sequence_name).reset_to([cards.highest_card_number, number].compact.max)
  end

  def reset_card_number_sequence
    reset_card_number_sequence_to(cards.highest_card_number)
  end

  def last_card_version
    card_versions.find(:first, :order => 'id DESC')
  end

  def time_zone
    zone = super
    zone.blank? ? ActiveSupport::TimeZone.new(Time.now.gmt_offset).name : zone
  end

  def time_zone_obj
    ActiveSupport::TimeZone.new(time_zone)
  end

  def utc_to_local(time)
    time_zone_obj.utc_to_local(time)
  end

  def today
    Clock.today(time_zone_obj)
  end

  def humanize_date_format
    date_format.gsub(/%d/, 'dd').gsub(/%m/, 'mm').gsub(/%Y/, 'yyyy').gsub(/%y/, 'yy').gsub(/%b/, 'mmm')
  end

  def transitions_dependent_upon_property_definitions_belonging_to_card_types(card_types, property_definitions)
    transitions.select{|t| t.card_type == nil || card_types.include?(t.card_type)}.select do |transition|
      property_definitions.any? { |prop_def| transition.uses_property_definition?(prop_def) }
    end
  end

  def card_defaults_dependent_upon_property_definitions_belonging_to_card_types(card_types, property_definitions)
    card_defaults.select { |t| t.card_type == nil || card_types.include?(t.card_type)}.select do |defaults|
      property_definitions.any? { |prop_def| defaults.uses_property_definition?(prop_def) }
    end
  end

  def destroy_transitions_dependent_upon_property_definitions_belonging_to_card_types(card_types, property_definitions)
    transitions_dependent_upon_property_definitions_belonging_to_card_types(card_types, property_definitions).each(&:destroy)
  end

  def destroy_card_default_actions_dependent_upon_property_definitions_belonging_to_card_types(card_types, property_definitions)
    card_types.each { |type| type.card_defaults.destroy_unused_actions((type.property_definitions - property_definitions)) }
  end

  def aggregate_associated_property_definitions
    aggregate_property_definitions_with_hidden.collect(&:associated_property_definitions).flatten.compact.uniq
  end

  v1_serializes_as :complete => [:id, :name, :identifier, :description, :created_at, :updated_at, :created_by_user_id, :modified_by_user_id, :keywords,
                                 :template, :email_address, :email_sender_name, :date_format, :time_zone, :precision, :anonymous_accessible, :auto_enroll_user_type,
                                 :card_versions_table, :cards_table],
                   :compact => [:name, :identifier, :id]

  v2_serializes_as :complete => [:name, :identifier, :description, :created_at, :updated_at, :created_by, :modified_by, :keywords,
                                 :template, :email_address, :email_sender_name, :date_format, :time_zone, :precision, :anonymous_accessible, :auto_enroll_user_type],
                   :compact => [:name, :identifier]
  compact_at_level 0

  conditionally_serialize :subversion_configuration, :if => Proc.new { |project| project.send(:subversion_configuration) }

  def as_lightweight_model
    ActiveRecord::XmlSerializer.new(self, :only => [:name, :identifier]).to_s do |serializer|
      serializer.card_types do
        self.card_types.each { |card_type| card_type.serialize_lightweight_attributes_to(serializer) }
      end
      serializer.property_definitions do
        (self.all_property_definitions + self.predefined_property_definitions).each { |prop_def| prop_def.serialize_lightweight_attributes_to(serializer) }
      end
      serializer.users do
        self.users.each { |user| user.serialize_lightweight_attributes_to(serializer) }
      end
      serializer.project_variables do
        self.project_variables.each { |pv| pv.serialize_lightweight_attributes_to(serializer) }
      end
    end
  end

  def user_prop_values
    return [] unless self.team
    key = Keys::UserPropertyValues.new.path_for(self)
    ThreadLocalCache.get(key) do
      Cache.get(key) do
        select = [:id, :name, :login, :email, :icon].map{|c| "#{User.quoted_table_name}.#{c}"}.join(', ')
        order = [:name, :login].map {|c| "LOWER(#{User.quoted_table_name}.#{c})"}.join(', ')
        self.users.find(:all, :select => select, :order => order)
      end
    end
  end

  def indexed_property_names
    properties_to_index.map(&:name).map(&:downcase)
  end

  def properties_to_index
    all_property_definitions.select { |pd| [EnumeratedPropertyDefinition, UserPropertyDefinition, TextPropertyDefinition].include? pd.class}
  end

  def feed_title
    "Mingle Events for Project: #{name}"
  end

  def strip_whitespace_and_underscores_from_start_and_end
    self.identifier.strip!

    if identifier_was_generated_from_name? && (self.name.strip != self.name)
      number_of_leading_spaces = self.name.size - self.name.lstrip.size
      number_of_trailing_spaces = self.name.size - self.name.rstrip.size

      # remove leading and trailing underscores
      self.identifier.gsub!(/^_{#{number_of_leading_spaces}}/, '')
      self.identifier.gsub!(/_{#{number_of_trailing_spaces}}+$/, '')
    end

    if self.identifier =~ /\A_+\z/
      self.identifier = "proj".uniquify[0..29]
    end

    self.name.strip!
    self.name = self.name.trim
  end

  def self.generate_identifier(name)
    candidate = name.gsub(ALLOWED_CHARACTERS_IN_IDENTIFIER, '_').downcase
    if candidate =~ /^\d.*/
      candidate = "project_" + candidate
    end
    candidate
  end

  def users_map
      Hash[users.map{|user| [user.login.downcase, user]}]
  end
  memoize :users_map

  def self.has_projects_admin?
    sql = SqlHelper.sanitize_sql(
        "SELECT COUNT(*)  FROM #{connection.quote_table_name('users')}
                  INNER JOIN #{connection.quote_table_name('member_roles')}
                        ON #{connection.quote_column_name('member_roles.member_id')} = #{connection.quote_column_name('users.id')}
                    WHERE LOWER(#{connection.quote_column_name('member_roles.permission')}) = ?", 'project_admin'
    )
    result = connection.execute(sql).first
    result['count'].to_i > 0
  end

  private

  def create_first_card_type_if_there_is_none
    card_types.create!(:name => 'Card') if card_types.blank?
  end

  def select_property_definitions_of_type(klass, options={:include_hidden => true})
    all_property_definitions.select { |pd| pd.class == klass && (options[:include_hidden] || !pd.hidden?) }
  end

  def forbidden_attribute_names
    ['icon', 'hidden', 'secret_key', 'corruption_checked', 'corruption_info', 'cards_table']
  end

  # see technical task 4809 for an understanding of this method
  def remove_duplicate_card_types(card_type)
    self.card_types.uniq!
  end

  # this is unfortunately duplicated in application.js (String.prototype.toIdentifier); change the other if you change this
  def identifier_was_generated_from_name?
    generated_identifier = self.name.gsub(/[^a-zA-Z0-9]/, '_').downcase
    if generated_identifier =~ /^\d.*/
      generated_identifier = "project_" + generated_identifier
    end
    self.identifier == generated_identifier
  end

  def create_card_number_sequence
    TableSequence.create(:name => card_number_sequence_name)
  end

  def delete_card_number_sequence
#project imported will create project by sql, so no card_number_sequence_name until you ask for the first card number
    if seq = TableSequence.find_by_name(card_number_sequence_name)
      seq.destroy
    end
  end

  def card_number_sequence_name
    "project_#{id}_card_numbers"
  end

  def destroy_taggings
    tags.each { |tag| tag.taggings.destroy_all }
  end

  def authorize_property_definition_creation(options)
    raise UserAccess::NotAuthorizedException.new("Error creating custom property #{options[:name].bold}. You must be a project administrator to create custom properties.") unless admin?(User.current)
  end

  def generate_secret_key_if_no_one
    unless secret_key
      generate_secret_key
    end
  end

  def validate_conflicts_with_mingle_internal_prefix
    errors.add(:identifier, 'reserved for internal Mingle use') if identifier =~ INTERNAL_TABLE_PREFIX_PATTERN
  end

  def validate_precision
    return unless respond_to?(:precision)
    raw_precision = send("precision_before_type_cast")
    errors.add(:precision, 'must be an integer between 0 and 10') unless ('0'..'10').to_a.include?(raw_precision.to_s)
  end

  def repository_configuration
    plugin = MinglePlugins::Source.find_for(self)
    RepositoryConfiguration.new(plugin) if plugin
  end
  memoize :repository_configuration

  def subversion_configuration
    return unless repository_configuration
    return unless repository_configuration.plugin.is_a?(SubversionConfiguration)
    repository_configuration.plugin
  end

  def set_hidden_to_true_if_it_is_nil
    self.hidden = true if self.hidden.nil?
  end
end

require 'project/rebuild_card_revision_link_observer'
