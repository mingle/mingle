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

class PropertyDefinition < ActiveRecord::Base
  include SecureRandomHelper
  include PropertyDefinitionSupport

  COLUMN_NAME_MAX_LEN = 40 # Derby: 128; mysql: 64; postgres8: 64; sql server 2000: 128; DB2 v8.1: 128; oracle9i: 30;
  INVALID_NAME_CHARS = '\[\]\"&=#;'
  VALID_NAME_PATTERN = /^([^#{INVALID_NAME_CHARS}]+)$/

  subclass_responsibility :validate_card, :name_values, :label_values_for_charting, :support_inline_creating
  belongs_to :project
  include ProjectAssociationOptimization

  has_many :property_type_mappings, :order => :position, :dependent => :destroy
  has_many :variable_bindings, :dependent => :destroy
  has_many :project_variables, :through => :variable_bindings
  has_many :card_defaults_actions, :class_name => "::PropertyDefinitionTransitionAction", :foreign_key => 'target_id', :dependent => :destroy

  strip_on_write
  #todo bug: all sub classes are not defined validations, what we should do?
  use_database_limits_for_all_attributes :except => [:name, :type]
  before_validation_on_create :generate_column_name
  validates_presence_of :name
  validates_length_of :name, :maximum => COLUMN_NAME_MAX_LEN, :allow_nil => true

  validate :valid_ruby_name?, :null_is_zero_only_set_for_formulas?
  validates_format_of :name, :with => VALID_NAME_PATTERN, :message => "should not contain '&', '=', '#', '\"', ';', '[' and ']' characters", :if => Proc.new{|pd| !pd.name.blank?}
  validates_format_of :column_name, :with => /[0-9A-Za-z]/, :if => Proc.new{|pd| !pd.name.blank?}
  validates_uniqueness_of :column_name, :scope => 'project_id'
  before_save :clear_formula_columns, :clear_dependant_formulas_column

  # Even though only agg properties use this column, we need to call serialize here (on its base class).  If the base class's dependant_formulas
  # is generated first and this serialize line isn't here, the generated method will not serialize and deserialize.  Then, this same method will
  # be used by aggregate property definition instead of generating its own version that *does* serialize and deserialize.
  #
  # This is a workaround for Rails bug https://rails.lighthouseapp.com/projects/8994/tickets/3169-attributes-are-not-serialized-in-sti-subclasses-in-production-mode
  # We have written a test in aggregate_property_definition_test (test_can_deserialize_dependant_formulas_after_using_the_base_class).
  serialize :dependant_formulas

  v1_serializes_as :complete => [:id, :name, :description, :data_type, :is_numeric?, :hidden?, :restricted?, :transition_only?, :project_id, :column_name, :position, :property_values_description],
                   :compact => [:name, :position, :data_type, :is_numeric?],
                   :element_name => 'record'
  additionally_serialize :complete, [:formula], 'v1'
  v2_serializes_as :complete => [:id, :name, :description, :data_type, :is_numeric?, :hidden?, :restricted?, :transition_only?, :project, :column_name, :position, :property_values_description, :card_types],
                   :compact => [:name, :position, :data_type, :is_numeric?],
                   :element_name => 'property_definition'

  def tooltip
    result = self.name
    if self.respond_to?(:description) && !self.description.blank?
      result = "#{result}: #{self.description}"
    end
    result = "#{result} tree" if self.is_a?(TreeBelongingPropertyDefinition)
    result
  end

  def clear_formula_columns
    self.formula = nil
  end

  def clear_dependant_formulas_column
    self.dependant_formulas = nil unless aggregated?
  end

  def null_is_zero_only_set_for_formulas?
    if null_is_zero? && !self.is_a?(FormulaPropertyDefinition)
      errors.add :null_is_zero, "is only valid for a formula"
      return false
    end
  end

  # predefined properties can set this to false, it's not persistent though
  attr_accessor :editable, :is_predefined

  class InvalidValueException < StandardError; end

  class << self

    def create_new_enumeration_values_from(property_names_and_values, project)
      property_names_and_values.each do |property_def_name, value|
        next if EnumerationValue::ILLEGAL_VALUES.include?(value)
        property_definition = project.find_property_definition(property_def_name, :with_hidden => true)
        property_definition.create_value_if_not_exist(value) if property_definition.respond_to?(:create_value_if_not_exist)
      end
    end

    def create_card_relationship_property_definition(options)
      CardRelationshipPropertyDefinition.create(options.merge(current_scoped_methods[:create]))
    end

    def create_text_list_property_definition(options)
      EnumeratedPropertyDefinition.create(options.merge(current_scoped_methods[:create]))
    end

    def create_any_text_property_definition(options)
      TextPropertyDefinition.create(options.merge(current_scoped_methods[:create]))
    end

    def create_number_list_property_definition(options)
      EnumeratedPropertyDefinition.create(options.merge(current_scoped_methods[:create]).merge(:is_numeric => true))
    end

    def create_any_number_property_definition(options)
      TextPropertyDefinition.create(options.merge(current_scoped_methods[:create]).merge(:is_numeric => true))
    end

    def create_date_property_definition(options)
      DatePropertyDefinition.create(options.merge(current_scoped_methods[:create]))
    end

    def create_formula_property_definition(options)
      FormulaPropertyDefinition.create(options.merge(current_scoped_methods[:create]))
    end

    def create_user_property_definition(options)
      UserPropertyDefinition.create(options.merge(current_scoped_methods[:create]))
    end

    def create_card_property_definition(options)
      TreeRelationshipPropertyDefinition.create(options.merge(current_scoped_methods[:create]))
    end

    def create_aggregate_property_definition(options)
      AggregatePropertyDefinition.create(options.merge(current_scoped_methods[:create]).merge(:is_numeric => true))
    end

    def create_api_property_definition(options)
      ApiPropertyDefinition.create(Project.current, options)
    end

    def predefined?(name)
      return false unless name.respond_to?(:to_str)
      PredefinedPropertyDefinitions::TYPES.keys.include?(name.to_str.downcase.gsub(/\W/, '_'))
    end

    def excel_importable?
      true
    end

    def tree_sort(property_definitions)
      sorted_properties = []
      relationship_properties, normal_properties = property_definitions.partition { |pd| pd.is_a?(TreeRelationshipPropertyDefinition) }
      special_properties, normal_properties = normal_properties.partition { |pd| pd.is_a?(CardTypeDefinition) }
      relevant_trees = relationship_properties.collect { |pd| pd.tree_configuration }.uniq

      sorted_properties += special_properties + normal_properties.smart_sort_by(&:name)

      relevant_trees.smart_sort_by(&:name).each do |tree|
        tree_properties = relationship_properties.select { |pd| pd.tree_configuration == tree }
        sorted_properties += tree_properties.smart_sort_by(&:position)
      end

      sorted_properties
    end

    # Used for generating naming route for all property_definition subclass
    def model_name
      @model_name ||= ActiveSupport::ModelName.new(PropertyDefinition.name)
    end
  end

  #be careful, we have to invoke update_card_by_obj now, it's template method and the code exists suppose it must be invoked
  def update_card(card, value, options = {})
    begin
      update_card_by_obj(card, property_type.find_object(value))
    rescue InvalidValueException => e
      card.errors.add_to_base("#{name}: #{e.message}")
    end
  end

  def update_card_by_obj(card, obj)
    return if value(card) == obj
    card.send(:write_attribute, column_name, obj)
  end

  def transition_only_for_updating_card?(card=nil)
    transition_only? && !project.admin?(User.current) && (card ? card.invalid_for_updating_transition_only_property? : true)
  end

  def update_card_with_transition_only_restriction(card, value, options = {})
    if transition_only_for_updating_card?(card) && value(card) != property_type.find_object(value)
      card.errors.add_to_base("#{name}: is a transition only property.")
    end
    update_card_without_transition_only_restriction(card, value, options)
  end
  alias_method_chain :update_card, :transition_only_restriction

  def attemped_to_create_plv(card_value)
    "#{self.name.escape_html}: #{card_value.escape_html.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property.".html_safe
  end

  def attemped_to_create_plv_from_transition(card_value)
    "#{self.name.escape_html}: #{card_value.escape_html.bold} is an invalid value. Value cannot both start with '(' and end with ')'".html_safe
  end

  def field_name
    name
  end

  def index_column?
    false
  end

  def can_use_with_card_type?(card_type)
    card_types.include? card_type
  end

  def card_types
    property_type_mappings.collect(&:card_type)
  end

  def card_type_names
    card_types.collect(&:name)
  end

  def card_types=(card_types)
    if errors = errors_at_prospect_of_card_type_disassociation(self.card_types - card_types)
      raise errors
    end
    property_type_mappings.delete_if { |ctpd| card_types.include?(ctpd.card_type) }.each(&:destroy)

    property_type_mappings.reload
    (card_types - property_type_mappings.collect(&:card_type)).each do |card_type|
      property_type_mappings.create(:card_type => card_type)
    end
  end

  def name?(property_name)
    self.name.ignore_case_equal? property_name.to_s
  end

  def nullable?
    true
  end

  def editable?
    editable
  end

  def calculated?
    false
  end

  def tree_special?
    false
  end

  def predefined?
    PropertyDefinition.predefined?(self.name)
  end

  def generate_column_name
    return if name.blank? # rely upon validates_presence_of :name
    self.ruby_name = project.card_schema.unique_column_name_from_name(name, 'cp')
    self.column_name = connection.column_name(self.ruby_name)
  end

  def downcase_column_name
    self.column_name.downcase!
  end

  def column_type
    :string
  end

  def quoted_column_name
    "#{Project.connection.quote_column_name(column_name)}"
  end

  def valid_ruby_name?
    not project.card_schema.invalid_identifier?(ruby_name)
  rescue
    return false
  end

  def validate
    errors.add :name, "#{name.bold} is a reserved property name" if self.class.predefined?(name)
    errors.add :name, "cannot be '_'" if self.name == '_'
    errors.add :name, "has already been taken by tree name" if project.tree_configurations.collect(&:name).any? { |tree_name| tree_name.ignore_case_equal?(self.name) }
  end

  validates_uniqueness_of :name, :scope => :project_id, :case_sensitive => false, :message => 'has already been taken'

  def value?(card)
    !value(card).nil?
  end

  def value(card)
    property_type.find_object(db_identifier(card))
  end

  def indexable_value(card)
    value(card)
  end

  def db_identifier(card)
    card.send(:read_attribute, column_name)
  end

  def remove_value(card, options = {})
    card.send(:write_attribute, column_name, nil)
  end

  def validate_card(card)
    # can be overridden by subclasses
  end

  def component_property_definitions(accumulator)
    []
  end

  def validate_transition_action(action)
    return unless property_type.respond_to?(:validate)
    property_type.validate(action.value).each do |e|
      message = "Property to set #{self.name.bold}: #{e}"
      action.errors.add_to_base(message)
    end
  end

  def validate_transition_prerequisite(prerequisite)
    return unless property_type.respond_to?(:validate)
    return if prerequisite.project_variable
    property_type.validate(prerequisite.value).each {|e| prerequisite.errors.add_to_base("Required property #{self.name.bold}: #{e}") }
  end

  def card_count
    return 0 unless project.card_schema.column_defined_in_card_table?(column_name)
    Card.connection.select_value("SELECT count(*) FROM #{Card.quoted_table_name} WHERE #{self.quoted_column_name} IS NOT NULL").to_i
  end

  def transitions
    project.transitions.select { |transition| transition.uses_property_definition?(self) }
  end

  def name=(new_name)
    # important to do renaming of associated objects before
    # changing my own name in order that they be valid when loaded.
    if name && name != new_name && record_exists?
      update_changes_table_on_name_change(name, new_name)
      update_saved_views_on_name_change(new_name)
      update_history_subscriptions_on_name_change(new_name)
      update_formula_property_definitions_on_name_change(new_name)
      update_aggregate_condition_on_name_change(new_name)
      FullTextSearch.index_cards(project)
    end
    write_attribute(:name, new_name)
  end

  def destroy
    Project.transaction do
      project.transitions.select{|transition| transition.uses_property_definition?(self) }.each(&:destroy)
      project.transitions.reload
      project.card_list_views.select{|view| view.uses?(self)}.each(&:destroy)
      project.card_list_views.reload
      project.history_subscriptions.each do |subscription|
        subscription.destroy if subscription.filter_property_names.ignore_case_include?(name)
      end
      #clear column to remove usage of property values
      project.card_schema.clear_column(column_name)
      super
      ProjectCacheFacade.instance.clear_cache(project.identifier)
      remove_property_changes

      CacheKey.touch(:structure_key, project)
      #remove column as last action as it would commit the transaction
      retryable(:tries => 3, :sleep => 0.1) do |retries, exception|
        Rails.logger.info "Trying to remove column #{column_name} from project #{project.identifier.inspect} cards table, try #{retries + 1}"
        Rails.logger.warn %Q{
          Failed with #{exception.message} while removing column, backtrace:
#{exception.backtrace.join("\n")}
        } if exception
        project.card_schema.remove_column(column_name, index_column?)
      end
    end

    project.reload
    FullTextSearch.index_cards(project)
  end

  def deletion
    deletion = Deletion.new(self)
  end

  def deletion_blockings
    used_by_formulas = project.formula_property_definitions_with_hidden.using(name)
    project_aggregates = project.aggregate_property_definitions_with_hidden
    used_by_aggregates_in_target = project_aggregates.select{ |prop_def| prop_def.target_property_definition == self }.compact
    used_by_aggregates_in_condition = project_aggregates.select{ |prop_def| prop_def.condition_properties.include? self }.compact

    Deletion::Blockings.new.tap do |blockings|
      blockings.add_reasons used_by_formulas, :link_name => 'card property management', :used_as  => 'a component property'
      blockings.add_reasons project.favorites.of_team.of_card_list_views.using(self).collect(&:favorited).smart_sort_by(&:name), :link_name => 'team favorites & tabs management', :used_in => 'team favorite'
      blockings.add_reasons project.tabs.of_card_list_views.using(self).collect(&:favorited).smart_sort_by(&:name), :link_name => 'team favorites & tabs management', :used_in => 'tab'
      blockings.add_reasons used_by_aggregates_in_condition, :link_name => 'configure aggregate properties', :used_in => "the condition of"
      blockings.add_reasons used_by_aggregates_in_target, :link_name => 'configure aggregate properties', :used_as => "the target property"
    end
  end

  def deletion_effects
    [].tap do |effects|
      if (card_count = self.card_count) > 0
        warning = "#{"Important".bold}: values for this property cannot be recovered and will no longer be displayed in history. If you wish to maintain history related to this property please use the hide property feature instead of continuing with this deletion."
        effects << Deletion::Effect.new(Card, :count => card_count, :additional_notes => warning)
      end

      if (transitions = self.transitions).any?
        effects << Deletion::Effect.new(Transition, :collection => self.transitions, :action => 'deleted')
      end

      if (project_variables = self.project_variables).any?
        effects << Deletion::Effect.new(ProjectVariable, :collection => self.project_variables, :action => 'disassociated')
      end

      effects << Deletion::StaticEffect.new("Pages and tables/charts that use this property will no longer work.")
      effects << Deletion::StaticEffect.new("Previously subscribed atom feeds that use this property will no longer provide new data.")
      effects << Deletion::StaticEffect.new("Card versions previously containing only changes to this property will no longer appear in history.")
      effects << Deletion::StaticEffect.new("Any personal favorites using this property will be deleted too.")
    end
  end

  def blockings_when_dissociate_card_types(deleted_card_types)
    blockings = Deletion::Blockings.new
    used_by_formulas = affected_formulas_when_disassociate_card_types(deleted_card_types)
    affected_aggregates = affected_aggregates_when_disassociate_card_types(deleted_card_types)
    used_by_aggregates_in_target = affected_aggregates.select{ |prop_def| prop_def.target_property_definition == self }.compact
    used_by_aggregates_in_condition = affected_aggregates.select{ |prop_def| prop_def.condition_properties.include? self }.compact
    blockings.add_reasons used_by_formulas, :link_name => 'card property management', :used_as  => 'a component property', :source => name
    blockings.add_reasons used_by_aggregates_in_condition, :link_name => 'configure aggregate properties', :used_in => "the condition of", :source => name
    blockings.add_reasons used_by_aggregates_in_target, :link_name => 'configure aggregate properties', :used_as => "the target property", :source => name
    blockings
  end

  def has_card_type?(card_type)
    card_type_name = card_type.respond_to?(:name) ? card_type.name : card_type
    card_types.detect{|ct| ct.name.downcase == card_type_name.downcase}
  end

  def has_one_of_card_types?(card_type_names)
    card_type_names.any? { |card_type_name| has_card_type?(card_type_name) }
  end

  def card_types_with_remove_not_applicable_card_values_and_delete_dependent_transitions=(new_card_types)
    deleted_card_types = card_types.select do |current_card_type|
      !new_card_types.include?(current_card_type)
    end
    if deleted_card_types.any?
      remove_not_applicable_card_values(deleted_card_types)
      project.destroy_transitions_dependent_upon_property_definitions_belonging_to_card_types(deleted_card_types, [self])
      project.destroy_card_default_actions_dependent_upon_property_definitions_belonging_to_card_types(deleted_card_types, [self])
      remove_card_types_from_formulas_dependent_on_this_property_definition(deleted_card_types)
    end
    self.card_types_without_remove_not_applicable_card_values_and_delete_dependent_transitions = new_card_types
  end
  alias_method_chain :card_types=, :remove_not_applicable_card_values_and_delete_dependent_transitions

  def global?
    project.card_types.reload unless project.card_types.loaded?
    card_types.size == project.card_types.size
  end

  def transitionable?
    true
  end

  def groupable?
    true
  end

  def colorable?
    true
  end

  def include_association
    nil
  end

  def label_values_for_charting
    values
  end

  def comparison_value(view_identifier)
    view_identifier
  end

  def mql_select_column_value(value)
    value
  end

  def numeric_comparison_for?(value)
    false
  end

  def clone_value(from_card, to_card)
    to_card.send(:write_attribute, column_name, from_card.send(:read_attribute, column_name))
  end

  def replace_values(old_value, new_value, options = {:bypass_versioning => false})
    cards_criteria = SqlHelper.sanitize_sql("WHERE #{quoted_column_name} = ?", old_value)
    updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name} #{cards_criteria})"))
    updater.update_properties({self.name => new_value}, {:bypass_versioning => options[:bypass_versioning]})
  end

  def managable?
    tree_configuration_id.nil?
  end

  def support_filter?
    false
  end

  def data_type
    property_type.to_s
  end

  def sort_value(property_value)
    property_type.sort_value(property_value)
  end

  def serialize_lightweight_attributes_to(serializer)
    serializer.property_definition do
      serializer.id id
      serializer.name name
      serializer.description description
      serializer.type_description describe_type
      serializer.values do
        serialize_light_property_values_on(serializer)
      end
    end
  end

  def errors_at_prospect_of_card_type_disassociation(disassociated_card_types)
    adversely_affected_aggregates = affected_aggregates_when_disassociate_card_types(disassociated_card_types).collect(&:name).sort
    if adversely_affected_aggregates.any?
      %{Property #{self.name.bold} cannot be updated because it is currently used by #{adversely_affected_aggregates.collect(&:bold).join(', ')}.}
    end
  end

  def affected_aggregates_when_disassociate_card_types(disassociated_card_types)
    project.aggregate_property_definitions_with_hidden.select do |pd|
      (aggregates_target_is_us?(pd) || aggregates_condition_use_us?(pd) || aggregates_target_is_formula_that_depends_on_us(pd)) && aggregate_relies_on_disassociated_card_types?(pd, disassociated_card_types)
    end
  end

  def affected_formulas_when_disassociate_card_types(disassociated_card_types)
    project.formula_property_definitions_with_hidden.select do |formula_prop_def|
      formula_prop_def.uses?(self) && formula_prop_def.card_types.any?{|card_type| disassociated_card_types.include?(card_type)}
    end
  end

  def update_changes_table_on_name_change(previous, current)
    statement = SqlHelper.sanitize_sql(%Q{
      UPDATE changes
         SET field = ?
       WHERE field = ?
         AND type = 'PropertyChange'
         AND exists (
          SELECT 1
            FROM events
           WHERE changes.event_id = events.id
             AND events.deliverable_id = ?
        )
    }, current, previous, project_id)
    connection.execute(statement)
  end
  private

  def update_saved_views_on_name_change(new_name)
    project.card_list_views.each do |view|
      view.rename_property(name, new_name)
      view.save!
    end
  end

  def update_formula_property_definitions_on_name_change(new_name)
    project.formula_property_definitions_with_hidden.each do |property_definition|
      property_definition.rename_property(name, new_name)
      FormulaPropertyDefinition.skip_callback(:save_dependent_formulas_on_aggregates) do
        FormulaPropertyDefinition.skip_callback(:make_formula_stale_if_dependant_aggregate_is_stale) do
          FormulaPropertyDefinition.skip_callback(:update_cards_if_null_is_zero_changed) do
            property_definition.save_without_validation!
          end
        end
      end
    end
  end

  def update_aggregate_condition_on_name_change(new_name)
    project.aggregate_property_definitions_with_hidden.each do |aggregate_definition|
      aggregate_definition.rename_dependent_property(name, new_name)
      aggregate_definition.save_without_validation!
    end
  end

  def aggregates_target_is_formula_that_depends_on_us(pd)
    return false if pd.is_count || !pd.target_property_definition.formulaic?
    pd.target_property_definition.uses?(self)
  end

  def aggregate_relies_on_disassociated_card_types?(pd, disassociated_card_types)
    disassociated_card_types.include?(pd.aggregate_scope) || (pd.descendants_that_have_property_definition(self) - disassociated_card_types).empty?
  end

  def aggregates_target_is_us?(aggregate_property_definition)
    aggregate_property_definition.target_property_definition == self
  end

  def aggregates_condition_use_us?(aggregate_property_definition)
    aggregate_property_definition.condition_properties.include?(self)
  end

  def serialize_light_property_values_on(serializer)
    light_property_values.each do |value|
      serializer.value do
        serializer.property_definition_id(id)
        serializer.display_value(value.display_value)
        serializer.db_identifier(value.db_identifier)
        serializer.url_identifier(value.url_identifier)
        serializer.color(value.color)
      end
    end
  end

  def update_history_subscriptions_on_name_change(new_name)
    project.history_subscriptions.each do |subscription|
      subscription.rename_property(name, new_name)
      subscription.save!
    end
  end

  def remove_not_applicable_card_values(deleted_card_types)
    return if deleted_card_types.compact.empty?

    criteria = SqlHelper.sanitize_sql("WHERE card_type_name IN (?)", deleted_card_types.collect(&:name))
    updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name} #{criteria})"))
    updater.update_properties({self.name => nil}, :system_generated_comment => "Property #{self.name} is no longer applicable to this card type.")
  end

  def remove_property_changes
    event_ids_for_project = 'tt' + random_32_char_hex
    TemporaryIdStorage.with_session do |session_id|
      project.connection.execute("INSERT INTO #{TemporaryIdStorage.table_name} (session_id, id_1) (SELECT '#{session_id}', id FROM #{Event.table_name} WHERE deliverable_id = #{project.id})")
      delete_changes_sql = "DELETE FROM #{Change.table_name} WHERE field = ? AND type = 'PropertyChange' AND event_id IN (SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{session_id}')"
      project.connection.execute(SqlHelper.sanitize_sql(delete_changes_sql, name))
    end
  end

  def remove_card_types_from_formulas_dependent_on_this_property_definition(card_types)
    formula_property_definitions_using_property = project.formula_property_definitions_with_hidden.using(self.name)
    formula_property_definitions_using_property.each do |formula_property_definition|
      formula_property_definition.card_types = formula_property_definition.card_types - card_types
    end
  end

end
