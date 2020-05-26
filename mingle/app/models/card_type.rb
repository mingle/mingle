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

class CardType < ActiveRecord::Base
  acts_as_list :scope => :project

  belongs_to :project
  has_many :property_type_mappings, :order => :position, :dependent => :destroy
  has_many :transitions, :dependent => :destroy
  has_one :card_defaults, :dependent => :destroy
  named_scope :order_by_name, :order => 'lower(name)'

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => 'project_id', :case_sensitive => false

  before_create :assign_color
  after_update :update_on_name_change, :remove_outdated_card_default_actions
  after_save :clear_cache
  after_create :create_card_defaults
  after_destroy :update_card_versions

  attr_accessor :nature_reorder_disabled

  use_database_limits_for_all_attributes
  strip_on_write
  serializes_as :complete => [:id, :name, :color, :position, [:property_definitions_with_hidden, {:element_name => 'property_definitions'}]],
                :compact => [:name]
  compact_at_level 0

  def self.definition_class
    CardTypeDefinition
  end

  include ListReorderingSupport::EnumerationValueSupport
  alias_method_chain :save, :reorder_values
  alias_method_chain :save!, :reorder_values

  class << self
    # TODO: Is this method called????
    def exists_with_check_by_name?(id_or_condition = {})
      return true if id_or_condition.blank?
      return exists_without_check_by_name?(id_or_condition) unless String === id_or_condition
      self.count(:conditions => ['UPPER(card_types.name) = UPPER(?)', id_or_condition.trim]) > 0
    end
    alias_method_chain :exists?, :check_by_name

    def find_by_name(name)
      return unless name
      first :conditions => ["LOWER(name) = ? OR name = ?",
                            name.downcase, name]
    end
  end

  def create_card_defaults_if_missing
    create_card_defaults if card_defaults.nil?
  end

  def cards(options={})
    options = options.merge(:conditions => ["#{Card.quoted_table_name}.card_type_name = ?", name])
    project.cards.find(:all, options)
  end

  def card_ids
    sql = SqlHelper.sanitize_sql("SELECT id FROM #{Card.quoted_table_name} WHERE card_type_name = ? ORDER BY #{connection.quote_column_name('number')}", name)
    project.connection.select_values(sql).collect(&:to_i)
  end

  #TODO let's rename enumeration_value#value to name and then remove this method
  def value
    name
  end

  def validate
    property_definition_names = property_definitions_with_hidden_without_order.collect { |pd| pd.name.downcase }
    property_definitions_with_hidden_without_order.select { |pd| pd.respond_to? :used_property_definitions }.each do |formula_prop_def|
      formula_prop_def.used_property_definitions.each do |used_property_definition|
        unless property_definition_names.include?(used_property_definition.name.downcase)
          errors.add_to_base("The component property #{used_property_definition.name.to_s.bold} should be available to all card types that formula property #{formula_prop_def.name.to_s.bold} is available to")
        end
      end
    end
  end

  def property_definitions=(prop_defs)
    if errors = errors_at_prospect_of_property_disassociation(self.property_definitions - prop_defs)
      raise errors
    end
    property_type_mappings.delete_if { |ctpd| prop_defs.include?(ctpd.property_definition) }.each(&:destroy)
    property_type_mappings.reload
    clear_cached_results_for(:property_definitions_with_hidden)
    # property_type_mappings.each { |ctpd| ctpd.update_attribute('position', nil) }

    managable_prop_defs, unmanagable_prop_defs = prop_defs.partition { |pd| pd.managable? }

    (managable_prop_defs + unmanagable_prop_defs).each_with_index do |pd, index|
      ctpd = property_type_mappings.detect { |ctpd| ctpd.property_definition == pd }
      if ctpd
        ctpd.update_attribute('position', index + 1)
      else
        ctpd = add_property_definition pd
        self.new_record? ? ctpd.position = index + 1 : ctpd.update_attribute('position', index + 1)
      end
    end
  end

  def position_of(prop_def)
    mapping = property_type_mappings.find_by_property_definition_id(prop_def.id)
    mapping.position if mapping
  end

  def add_property_definition(prop_def)
    property_type_mappings.create :property_definition => prop_def
  end

  def property_definitions
    property_definitions_with_hidden.reject(&:hidden)
  end

  def enumerable_property_definitions
    property_definitions.select { |pd| EnumeratedPropertyDefinition === pd }
  end

  def managable_property_definitions
    property_definitions.select{ |pd| pd.managable? }
  end

  def managable_property_definitions_with_hidden
    property_definitions_with_hidden.select{ |pd| pd.managable? }
  end

  def managable_property_definitions=(pds)
    system_reserved = property_definitions_without_order - managable_property_definitions
    self.property_definitions = system_reserved + pds
  end

  def formula_property_definitions
    property_definitions.select(&:formulaic?)
  end

  def aggregate_property_definitions
    property_definitions_with_hidden.select(&:aggregated?)
  end

  def tree_relationship_properties
    tree_configurations.collect { |configuration| configuration.find_relationship(self) }.compact
  end

  def numeric_property_definitions(options = {})
    prop_defs = options[:with_hidden] ? property_definitions_with_hidden : property_definitions
    prop_defs.select(&:numeric?)
  end

  def property_definition_names
    property_definitions.collect(&:name)
  end

  # using property_definitions_with_hidden_without_order instead when you try to update this model
  # this method should only be used in the view to display property definitions with order, since we
  # cached the result.
  def property_definitions_with_hidden
    has_position, no_position = property_type_mappings.partition(&:position)
    has_position_pds = has_position.sort_by(&:position).collect(&:property_definition)
    no_position_pds = no_position.collect(&:property_definition).smart_sort_by(&:name)
    ordered_by_position = has_position_pds + no_position_pds
    tree_special, no_tree_special = ordered_by_position.partition(&:tree_special?)
    no_tree_special + tree_special
  end
  memoize :property_definitions_with_hidden

  def property_definitions_with_hiden_without_tree
    property_definitions_with_hidden.reject(&:tree_special?)
  end

  def property_definition
    Project.card_type_definition
  end

  def property_definitions_in_smart_order
    property_definitions.smart_sort_by(&:name)
  end

  def property_definitions_with_hidden_in_smart_order
    property_definitions_with_hidden.smart_sort_by(&:name)
  end

  def filterable_property_definitions_in_smart_order(options={})
    tree_relationship = options[:tree].find_relationship(options[:tree].card_types_before(self).last) if options[:tree]
    property_definitions.select do |pd|
      next unless pd.filterable?
      !(pd.tree_configuration_id && options[:tree]) || (pd == tree_relationship)
    end.smart_sort_by(&:name)
  end

  def property_definitions_with_remove_not_applicable_card_values_and_delete_dependent_transitions=(new_property_definitions)
    deleted_properties = property_definitions_with_hidden_without_order.reject do |current_prop_def|
      new_property_definitions.include?(current_prop_def)
    end

    if deleted_properties.any?
      remove_formula_properties_dependent_on_deleted_properties(new_property_definitions, deleted_properties)
      remove_not_applicable_card_values(deleted_properties)
      project.destroy_transitions_dependent_upon_property_definitions_belonging_to_card_types([self], deleted_properties)
    end

    self.property_definitions_without_remove_not_applicable_card_values_and_delete_dependent_transitions = new_property_definitions
  end
  alias_method_chain :property_definitions=, :remove_not_applicable_card_values_and_delete_dependent_transitions

  def destroy_with_validate
    can_be_destroy? ? self.destroy : errors.add_to_base("#{name} cannot be deleted because it is being used or is the last card type.")
  end

  def is_dissociated?
    card_count == 0 && card_tree_count == 0
  end

  def can_be_destroy?
    is_dissociated? && !last?
  end

  def card_count
    project.cards.count(:conditions => ["card_type_name = ?", name])
  end

  def tree_configurations
     project.tree_configurations.select{ |config| config.all_card_types.include?(self) }.smart_sort_by(&:name)
  end

  def card_tree_count
    tree_configurations.size
  end

  def last?
    self.project.card_types.size == 1
  end

  #todo: that's a hack for mysql 5.0.45, which auto give the not null column a default (empty string)
  # that causing the attribute default be blank instead of a nil
  # we need decide whether we want to live under this contrain or just simple drop support for that
  # mysql version
  def name
    super.blank? ? nil : super
  end

  def destroy
    Project.transaction do
      project.card_list_views.select{|view| view.uses_card_type?(self)}.each(&:destroy)
      project.history_subscriptions.each { |subscription| subscription.destroy if subscription.uses_card_type?(self) }
      card_defaults.destroy
      super
    end
  end

  # optimization
  def project
    return Project.current
  end

  # todo: get rid of this if we can figure out how to re-cache the association info on project activatation for has_one :card_defaults
  def card_defaults
    CardDefaults.find_by_card_type_id(id)
  end

  def is_type_card_query_condition
    CardQuery::ComparisonWithValue.new(CardQuery::Column.new('Type'), Operator::Equals.new, name)
  end

  def clear_cache
    clear_cached_results_for :property_definitions_with_hidden
  end

  def property_definitions_with_hidden_without_order
    property_type_mappings.collect(&:property_definition)
  end

  def property_definitions_without_order
    property_definitions_with_hidden_without_order.reject(&:hidden?)
  end

  def save_and_set_property_definitions(property_definitions)
    save_result = self.save
    if save_result
      self.property_definitions = property_definitions
      save_result = self.save
    end
    save_result
  end

  def serialize_lightweight_attributes_to(serializer)
    serializer.card_type do
      serializer.id id
      serializer.name name
      serializer.color(color ? color[1..-1] : nil)
      serializer.position position
      serializer.card_types_property_definitions do
        self.property_type_mappings.each { |ctpd| ctpd.serialize_lightweight_attributes_to(serializer) }
      end
    end
  end

  def errors_at_prospect_of_property_disassociation(disassociated_property_definitions)
    return if disassociated_property_definitions.empty?

    aggregates = adversely_affected_aggregates_by_property_definition_removal(disassociated_property_definitions)
    if aggregates.any?
      %{Card type #{self.name.bold} cannot be updated because it is currently used by #{aggregates.map(&:name).bold.join(', ')}.}
    end
  end

  def adversely_affected_aggregates_by_property_definition_removal(disassociated_property_definitions)
    project.aggregate_property_definitions_with_hidden.select do |pd|
      aggregate_relies_on_disassociated_property_definition?(pd, disassociated_property_definitions)
    end
  end

  private

  def aggregate_relies_on_disassociated_property_definition?(pd, disassociated_property_definitions)
    single_scope_aggregate_that_relies_on_disassociated_property_definition?(pd, disassociated_property_definitions) || all_descendants_scope_aggregate_that_relies_on_disassociated_property_definition?(pd, disassociated_property_definitions)
  end

  def single_scope_aggregate_that_relies_on_disassociated_property_definition?(pd, disassociated_property_definitions)
    disassociated_property_definitions.include?(pd.target_property_definition) && pd.aggregate_scope == self
  end

  def all_descendants_scope_aggregate_that_relies_on_disassociated_property_definition?(pd, disassociated_property_definitions)
    return false unless pd.aggregate_scope == AggregateScope::ALL_DESCENDANTS
    return false unless pd.target_property_definition
    return false unless disassociated_property_definitions.include?(pd.target_property_definition)
    card_types_that_still_have_property_definition = pd.descendants_that_have_property_definition(pd.target_property_definition) - [self]
    card_types_that_still_have_property_definition.empty?
  end

  def remove_not_applicable_card_values(deleted_property_definitions)
    criteria = SqlHelper.sanitize_sql("WHERE card_type_name = ?", self.name)
    updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name} #{criteria})"))
    props_to_nil = deleted_property_definitions.inject({}){|result, prop_def| result[prop_def.name] = nil; result}
    comment_start = if props_to_nil.size > 1
      "Properties #{props_to_nil.keys.smart_sort.join(', ')} are"
    else
      "Property #{props_to_nil.keys.first} is"
    end
    updater.update_properties(props_to_nil, :system_generated_comment => "#{comment_start} no longer applicable to card type #{self.name}.")
  end

  def update_on_name_change
    return unless name_changed?
    old_name, new_name = name_change

    project.card_schema.rename_column_value property_definition.column_name, old_name, new_name
    Change::rename_change_value self.project.id, property_definition.name, old_name, new_name

    project.card_list_views.each do |view|
      view.rename_property_value(property_definition.name, old_name, new_name)
      view.rename_card_type(old_name, new_name)
      view.save!
    end

    project.history_subscriptions.each do |subscription|
      subscription.rename_property_value(property_definition.name, old_name, new_name)
      subscription.save!
    end

    project.aggregate_property_definitions_with_hidden.each do |aggregate|
      aggregate.rename_card_type(old_name, new_name)
      aggregate.save_without_validation!
    end
  end

  def remove_outdated_card_default_actions
    card_defaults.destroy_unused_actions(property_definitions)
    true
  end

  def remove_formula_properties_dependent_on_deleted_properties(property_definitions_to_add, property_definitions_to_delete)
    formula_property_definitions = property_definitions_with_hidden_without_order.select { |pd| pd.is_a?(FormulaPropertyDefinition) }
    formula_property_definitions_that_will_be_removed_by_force = formula_property_definitions.select { |pd| pd.uses_one_of?(property_definitions_to_delete) }

    formula_property_definitions_that_will_be_removed_by_force.each do |formula_property_def|
      property_definitions_to_add.delete(formula_property_def)
      property_definitions_to_delete << formula_property_def
    end
    property_definitions_to_delete.uniq!
  end

  def create_card_defaults
    CardDefaults.create(:card_type_id => self.id, :project_id => project.id)
  end

  def update_card_versions
    sql = SqlHelper.sanitize_sql("UPDATE #{Card::Version.quoted_table_name} set card_type_name = ? where card_type_name = ?", "#{name} [deleted]", name)
    connection.execute(sql)
  end

  def assign_color
    self.color = Color.random(project.card_types.all.collect(&:color)) if color.blank?
  end
end
