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

class FormulaPropertyDefinition < PropertyDefinition

  class ArrayExt < Array
    def using(property_definition_name)
      select do |formula_prop_def|
        formula_prop_def.used_property_definitions.any? { |used_property_definition| used_property_definition.name.downcase == property_definition_name.downcase }
      end
    end
  end

  after_validation :save_numericness
  validate_on_update :ensure_uses_valid_property_definitions
  after_save :save_dependent_formulas_on_aggregates, :make_formula_stale_if_dependant_aggregate_is_stale, :update_cards_if_null_is_zero_changed
  after_destroy :flush_dependent_formulas_on_aggregates

  additionally_serialize :complete, [:formula, :null_is_zero], 'v2'

  def update_cards_if_null_is_zero_changed
    if null_is_zero_changed?
      reset_formula_cache
      old_formula = FormulaParser.new.parse(attributes['formula'], !null_is_zero)
      update_all_cards("(not set) changed from being evaluated as #{null_is_zero ? '(not set)' : '0'} to #{null_is_zero ? '0' : '(not set)'} for #{name}.", ids_of_cards_impacted_by_change_sql(old_formula, formula), false)
      recompute_affected_aggregates
    end
  end

  def clear_formula_columns
    # should not clear formula columns for this type.
  end

  def describe_type
    'Formula'
  end
  alias_method :type_description, :describe_type
  alias_method :property_values_description, :describe_type

  def save_numericness
    self.is_numeric = self.formula.output_type.numeric? if self.errors.empty? && (new_record? || attribute_changed?(:formula))
    true
  end

  def property_type
    PropertyType::CalculatedType.new(project, self)
  end

  def groupable?
    false
  end

  def colorable?
    false
  end

  def finite_valued?
    false
  end

  def lockable?
    false
  end

  def calculated?
    true
  end

  def formulaic?
    true
  end

  def numeric_comparison_for?(value)
    numeric?
  end

  def numeric?
    is_numeric
  end

  def date?
    self.formula.output_type.date?
  end

  def values
    return [] unless project.card_schema.column_defined_in_card_table?(column_name)
    formula.select_card_values(column_name)
  end

  def light_property_values
    []
  end

  def available_operators
    return Operator::Equals.name, Operator::NotEquals.name, Operator::LessThan.name, Operator::GreaterThan.name
  end

  def name_values
    []
  end
  alias_method :card_filter_options, :name_values

  def support_inline_creating?
    true
  end

  def filterable?
    false
  end

  def change_formula_to(new_formula)
    @previous_formula = attributes['formula']
    reset_formula_cache
    no_errors_on_formula_update = update_attributes!(:formula => new_formula) rescue false
    if @previous_formula != new_formula && no_errors_on_formula_update
      old_formula = FormulaParser.new.parse(@previous_formula, null_is_zero?)
      update_all_cards("#{name} changed from #{@previous_formula} to #{new_formula}", ids_of_cards_impacted_by_change_sql(old_formula, formula), old_formula.output_type != formula.output_type)
      recompute_affected_aggregates
    else
      no_errors_on_formula_update
    end
  end

  def formula
    @formula_cache ||= FormulaParser.new.parse(attributes['formula'], null_is_zero?)
  end

  def formula=(formula)
    super
    reset_formula_cache
  end

  def update_card_formula(card)
    return if value(card) == formula.value(card)
    value = formula.value(card).to_s
    value = value.to_s.to_num(project.precision).to_s if value && Formula::Number === formula.output_type
    update_card(card, value)
  end

  def value(card)
    to_output_format(super) if super
  end

  def to_output_format(value)
    formula.to_output_format(value)
  end

  def validate
    super
    if attributes['formula'].blank?
      self.errors.add_to_base("Formula cannot be blank.")
      return
    end

    begin
      unless formula.valid?
        formula.errors.each { |error| self.errors.add_to_base(error) }
        return
      end
    rescue Exception => e
      self.errors.add_to_base("The formula is not well formed. #{e.message.gsub(/parse error on value/, 'Unexpected characters encountered:')}.")
      return
    end

    unless self.formula.output_type.numeric? || aggregates_using_formula.empty?
      aggregates = aggregates_using_formula.collect { |aggregate| aggregate.name.bold }.sort
      self.errors.add_to_base("#{self.name.bold} cannot have a formula that results in a date, as it is being used in the following aggregate #{'property'.plural(aggregates.size)}: #{aggregates.join(', ')}")
    end

    validate_no_circular_references
  end

  def validate_no_circular_references
    self.errors.add_to_base("This formula #{self.name.bold} contains a circular reference. Formulas and aggregates cannot contain circular references.") if detect_circular_references_to(self)
  end

  include SqlHelper

  def update_all_cards(system_generated_comment = nil, card_filter_condition = nil, reset_column_values_to_null_before_update = nil, options = {})
    return if self.card_types.empty?
    card_type_names =  (options[:card_types] || self.card_types).collect { |card_type| card_type.name.upcase }
    bind_variables = (['?'] * card_type_names.size).join(', ')
    relevant_card_ids = sanitize_sql "IN (SELECT id FROM #{Card.quoted_table_name} WHERE UPPER(card_type_name) IN (#{bind_variables}))", *card_type_names
    relevant_card_ids += " AND ? IN (SELECT id FROM #{Card.quoted_table_name} WHERE #{card_filter_condition})" if card_filter_condition

    options = {:system_generated_comment => system_generated_comment}
    options[:reset_formula_columns_to_null_in_db_update_parameters] = reset_card_values_to_null_update_parameters if reset_column_values_to_null_before_update
    Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new(relevant_card_ids)).update_properties({self.name => self.formula.to_sql}, options)
  end

  def update_all_cards_of_type(card_type)
    update_all_cards(nil, nil, nil, {:card_types => [card_type]})
  end

  def update_property_sql(table_name = Card.table_name)
    "#{self.quoted_column_name} = #{formula.to_sql(table_name)}"
  end

  def used_property_definitions
    formula.used_property_definitions
  end

  def uses?(property_definition)
    self.used_property_definitions.any? { |pd| pd.name.downcase == property_definition.name.downcase }
  end

  def uses_one_of?(property_definitions)
    used_prop_defs = used_property_definitions.collect { |pd| pd.name.downcase }
    property_definitions.each do |pd|
      return true if used_prop_defs.include?(pd.name.downcase)
    end
    false
  end

  def rename_property(old_name, new_name)
    formula.rename_property(old_name, new_name)
    write_attribute(:formula, formula.to_s[1..-2])
    reset_formula_cache
  end

  def transitionable?
    false
  end

  def reload
    reset_formula_cache
    super
  end

  def detect_circular_references_to(property_definition)
    Formula::PropertyDefinitionDetector.new(formula).all_related_property_definitions([]).include?(property_definition)
  end

  def component_property_definitions(accumulator)
    result = Formula::PropertyDefinitionDetector.new(formula).all_related_property_definitions([])
    accumulator += result
    result.dup.select { |pd| pd.aggregated? }.each do |associated_aggregate_property_definition|
      result += Aggregate::PropertyDefinitionDetector.new(associated_aggregate_property_definition.associated_property_definitions).all_related_property_definitions(accumulator)
    end
    result
  end

  private
  def reset_card_values_to_null_update_parameters
    { :table => Card.table_name, :set => SqlHelper.sanitize_sql("#{self.column_name} = ?", nil) }
  end

  def ids_of_cards_impacted_by_change_sql(old_formula, new_formula)
    column_vs_column_not_equal_condition(old_formula.to_sql, new_formula.to_sql, :case_insensitive => true)
  end

  def uses_valid_property_definitions?
    return true if self.card_types.empty?
    (used_property_definitions.collect { |pd| pd.name.downcase } - all_valid_property_definitions).empty?
  end

  def ensure_uses_valid_property_definitions
    return false if self.errors.any?

    uses_valid_property_definitions?.tap do |is_valid|
      self.errors.add_to_base "The component property should be available to all card types that formula property is available to." unless is_valid
    end
  end

  def all_valid_property_definitions
    return [] if card_types.empty?

    self.card_types.collect { |ct| ct.property_definitions_with_hidden_without_order.collect(&:name) }.inject do |result, prop_def_names|
      result &= prop_def_names
    end.collect(&:downcase)
  end

  def reset_formula_cache
    @formula_cache = nil
  end

  def aggregates_using_formula
    project.aggregate_property_definitions_with_hidden.select { |agg_prop_def| agg_prop_def.target_property_definition == self }
  end

  def recompute_affected_aggregates
    aggregates_using_formula.each(&:update_cards)
  end

  def flush_dependent_formulas_on_aggregates
    project.aggregate_property_definitions_with_hidden.each do |aggregate_property_definition|
      aggregate_property_definition.remove_dependent_formula(self)
    end
  end

  def save_dependent_formulas_on_aggregates
    flush_dependent_formulas_on_aggregates
    directly_related_property_definitions = Formula::PropertyDefinitionDetector.new(self.formula).directly_related_property_definitions
    directly_related_property_definitions.each do |used_property_definition|
      used_property_definition.add_dependent_formula(self) if used_property_definition.aggregated?
    end
  end

  def make_formula_stale_if_dependant_aggregate_is_stale
    insert_columns = ['card_id', 'prop_def_id', 'project_id']
    select_columns = ['card_id', "#{self.id}", 'project_id']

    if connection.prefetch_primary_key?(StalePropertyDefinition)
      select_columns.unshift(connection.next_id_sql(StalePropertyDefinition.table_name))
      insert_columns.unshift('id')
    end

    sql = %{ insert into #{StalePropertyDefinition.table_name} (#{insert_columns.join(', ')})
             select #{select_columns.join(', ')}
             from stale_prop_defs
             where prop_def_id = ? and project_id = #{self.project.id}
          }

    used_property_definitions.each do |pd|
      next unless pd.aggregated?
      self.connection.execute(SqlHelper.sanitize_sql(sql, pd.id))
    end
  end
end
