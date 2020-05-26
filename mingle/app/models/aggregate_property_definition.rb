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

class AggregatePropertyDefinition < PropertyDefinition

  validates_presence_of :aggregate_card_type_id, :tree_configuration_id, :message => "must be selected"
  validates_inclusion_of :aggregate_type, :in => AggregateType::TYPES, :message => "must be selected"
  belongs_to :aggregate_card_type, :class_name => 'CardType', :foreign_key => 'aggregate_card_type_id'
  belongs_to :aggregate_scope, :class_name => 'CardType', :foreign_key => 'aggregate_scope_card_type_id'
  belongs_to :tree_configuration
  belongs_to :target_property_definition, :class_name => 'PropertyDefinition', :foreign_key => 'aggregate_target_id'
  # serializes_as :complete => [:id, :name, :description, :type, :is_numeric, :hidden, :restricted, :transition_only, :formula, :project_id, :column_name, :position, :valid_card_type_id, :tree_configuration_id, :aggregate_target_id, :aggregate_type, :aggregate_card_type_id, :aggregate_scope_card_type_id, :aggregate_condition],
  #               :compact => [:id, :name]

  after_create :add_to_aggregate_card_type

  attr_accessor :has_condition

  # Either Rails or bound variables (or both) seem to YAML encode an attribute on save, even if it hasn't been
  # deserialized (which would happen if you load an object and not reference the serialized attribute before
  # saving it again).  This hack should enforce the deserialization.
  def after_find
    self.dependant_formulas
  end

  class << self
    def aggregate_properties(project, card_tree, aggregate_card_type)
      find(:all, :conditions => ["project_id = ? and aggregate_card_type_id = ? and tree_configuration_id = ? ",
                                   project.id, aggregate_card_type.id, card_tree.id])
    end

    def update_aggregates_using_project_variable(project_variable)
      project_variable.project.aggregate_property_definitions_with_hidden.each do |aggregate_property_definition|
        aggregate_property_definition.update_cards if aggregate_property_definition.uses_plv?(project_variable)
      end
    end
  end

  def associated_property_definitions
    ([self.target_property_definition] + condition_properties).compact
  end

  def describe_type
    'Aggregate'
  end
  alias_method :type_description, :describe_type
  alias_method :property_values_description, :describe_type

  def numeric_comparison_for?(value)
    true
  end

  def numeric?
    is_numeric
  end

  def tree_special?
     true
  end

  def value(card)
    to_output_format(super) if super
  end

  def to_output_format(value)
    Aggregate.to_output_format(project, value)
  end

  def filterable?
    false
  end

  def name_values
    []
  end
  alias_method :light_property_values, :name_values

  def is_count
    aggregate_type == AggregateType::COUNT
  end

  def groupable?
    false
  end

  def colorable?
    false
  end

  def lockable?
    false
  end

  def support_inline_creating?
    true
  end

  def property_type
    PropertyType::CalculatedType.new(project, self)
  end

  def calculated?
    true
  end

  def finite_valued?
    false
  end

  def aggregated?
    true
  end

  def all_descendants?
    self.aggregate_scope.nil?
  end

  def children_only?
    !all_descendants?
  end

  def aggregate_type
    AggregateType.find_by_identifier(read_attribute(:aggregate_type))
  end

  def aggregate_type=(aggregate_type)
    if aggregate_type.respond_to?(:identifier)
      write_attribute(:aggregate_type, aggregate_type.identifier)
    else
      super
    end
  end

  def scopes_with_values
    [[AggregateScope::ALL_DESCENDANTS_NAME, AggregateScope::ALL_DESCENDANTS]] + valid_scopes.collect {|type| [type.name, type.id]}
  end

  def valid_scopes
    tree_configuration.card_types_after(aggregate_card_type)
  end

  def validate
    super

    validate_scope
    validate_condition
    validate_target_property
    validate_no_circular_references
  end

  def compute_aggregate(card_or_card_id)
    publisher.publish_card_message(card_or_card_id)
  end

  def compute_aggregates(cards)
    cards.each_slice(1000) do |slice|
      publisher.publish_card_messages("id in (#{slice.collect(&:id).join(', ')})")
    end
  end


  def values
    rows = self.connection.select_all("SELECT DISTINCT #{self.column_name} AS value, #{self.connection.as_number(self.column_name)} FROM #{Card.quoted_table_name} ORDER BY #{self.connection.as_number(self.column_name)}")
    rows.map do |row|
      project.to_num(row['value']) unless row['value'].nil?
    end.compact
  end

  def update_cards
    publisher.publish_card_messages card_ids_for_card_type_condition_sql
  end

  # this is expensive -- you likely should be using the update_cards method which scopes to tree membership
  def update_cards_across_project
    publisher.publish_project_message
  end

  def card_ids_for_card_type_condition_sql
    sql = %{
      lower(card_type_name) = ?
      AND id IN (SELECT card_id FROM #{TreeBelonging.quoted_table_name} WHERE tree_configuration_id = ?)
    }
    SqlHelper.sanitize_sql(sql, aggregate_card_type.name.downcase, self.tree_configuration_id)
  end

  def compute_card_aggregate_value(card, options = {})
    return nil if card.card_type != self.aggregate_card_type

    agg_card_types = aggregate_card_types
    return nil if agg_card_types.empty?

    aggregate = Aggregate.new(project, aggregate_type, target_property_definition)
    relationship = find_relationship(tree_configuration, aggregate_card_type) # do not switch this method back to tree_configuration.find_relationship
    aggregate_card_types_list = agg_card_types.collect{|ct| "'#{ct.name.downcase}'"}.join(',')

    conditions = %{
     (#{Card.quoted_table_name}.id IN (SELECT card_id FROM tree_belongings WHERE tree_configuration_id = #{tree_configuration_id}))
           AND LOWER(#{Card.quoted_table_name}.card_type_name) in (#{aggregate_card_types_list})
           AND #{Card.quoted_table_name}.#{relationship.column_name} = #{card.id}
           AND (#{aggregate_condition_sql})
    }
    aggregate.result_by_sql(conditions)
  end

  def update_or_destroy_by(card_type)
    if aggregate_scope == AggregateScope::ALL_DESCENDANTS
      update_cards
    elsif aggregate_scope == card_type
      destroy
    end
  end

  def component_property_definitions(accumulator)
    result = associated_property_definitions
    accumulator += result
    associated_property_definitions.select { |pd| pd.formulaic? }.each do |associated_formula_property_definition|
      result += Formula::PropertyDefinitionDetector.new(associated_formula_property_definition.formula).all_related_property_definitions(accumulator)
    end
    result
  end

  def add_dependent_formula(formula_property_definition)
    dependants = self.dependant_formulas || []
    dependants << formula_property_definition.id
    self.dependant_formulas = dependants.uniq
    self.save
  end

  def remove_dependent_formula(formula_property_definition)
    return if self.dependant_formulas.nil?
    self.dependant_formulas -= [formula_property_definition.id]
    self.save
  end

  def descendants_that_have_property_definition(property_definition)
    valid_scopes.select do |card_type|
      card_type.property_definitions_with_hidden_without_order.include?(property_definition)
    end
  end

  def condition_properties
    parsed_mql_condition.used_properties
  end

  def rename_dependent_property(old_name, new_name)
    self.aggregate_condition = parsed_mql_condition.rename_property_mql_conditions(old_name, new_name).mql
  end

  def rename_dependent_project_variable(old_name, new_name)
    self.aggregate_condition = parsed_mql_condition.rename_project_variable_mql_conditions(old_name, new_name).mql
  end

  def rename_card_type(old_name, new_name)
    self.aggregate_condition = parsed_mql_condition.rename_card_type_mql_conditions(old_name, new_name).mql
  end

  def rename_dependent_enumeration(property_definition, old_name, new_name)
    self.aggregate_condition = parsed_mql_condition.rename_property_value_mql_conditions(property_definition.name, old_name, new_name).mql
  end

  def detect_circular_references_to(property_definition)
    Aggregate::PropertyDefinitionDetector.new(associated_property_definitions).all_related_property_definitions([]).include?(property_definition)
  end

  def uses_plv?(project_variable)
    parsed_mql_condition.uses_plv?(project_variable)
  end

  def uses_property_value?(prop_name, value)
    parsed_mql_condition.uses_property_value?(prop_name, value)
  end

  def deletion_effects
    [Deletion::StaticEffect.new("any personal favorites using this property will be deleted too.")]
  end

  private

  def has_condition?
    has_condition == true
  end

  def aggregate_condition_sql
    aggregate_condition.blank? ?  "1 = 1" :
      "#{Card.quoted_table_name}.id IN (#{CardQuery.parse(self.aggregate_condition).to_card_id_sql})"
  end

  def parsed_mql_condition
    MqlFilters::MqlConditions.parse_mql_conditions(aggregate_condition)
  end

  def publisher
    @publisher ||= AggregatePublisher.new(self, User.current)
  end

  def validate_scope
    if (tree_configuration && aggregate_card_type && !tree_configuration.all_card_types.include?(aggregate_card_type))
      errors.add_to_base("Aggregate properties cannot be defined since #{aggregate_card_type.name.bold} is not on the tree")
    end

    if (tree_configuration && aggregate_card_type && tree_configuration.all_card_types.last == aggregate_card_type)
      errors.add_to_base("Aggregate properties cannot be defined since #{aggregate_card_type.name.bold} does not have any children")
    end

    unless (aggregate_scope_card_type_id.nil? || valid_scopes.collect(&:id).include?(aggregate_scope_card_type_id))
      errors.add_to_base("Aggregate properties must have a valid scope")
    end
  end

  def validate_condition
    begin
      errors.add "aggregate_condition", "cannot be blank" if has_condition? && aggregate_condition.blank?
      query = CardQuery.parse_as_condition_query(aggregate_condition)
      mql_validations = CardQuery::AggregateConditionValidations.new(query).execute
      mql_validations.each { |validation| errors.add_to_base(validation) }
      return if mql_validations.any?
      query.card_count
      query.to_sql
      @conditions_valid = true
    rescue Exception
      @conditions_valid = false
      errors.add "aggregate_condition", "is not valid. #{$!.message}"
    end
  end

  def validate_target_property
    if (aggregate_target_id.blank? && aggregate_type != AggregateType::COUNT)
      errors.add_to_base("Target property definition is required unless aggregate type is 'count'")
    end

    if (!aggregate_target_id.blank? && !target_property_definition.numeric?)
      errors.add_to_base("Aggregate property definition must be numeric")
    end

    if (target_property_definition && target_property_definition.aggregated?)
      errors.add_to_base("Aggregate properties cannot have another aggregate property (#{target_property_definition.name.bold}) as a target")
    end
  end

  def validate_no_circular_references
    return unless @conditions_valid
    associated_property_definitions.each do |associated_pd|
       next unless associated_pd.aggregated? || associated_pd.formulaic?
      errors.add_to_base("This aggregate #{self.name.bold} contains a circular reference. Formulas and aggregates cannot contain circular references.") if associated_pd.detect_circular_references_to(self)
    end
  end

  def add_to_aggregate_card_type
    aggregate_card_type.add_property_definition(self)
  end

  def aggregate_card_types
    if (!all_descendants?)
      [aggregate_scope]
    else
      next_types = tree_configuration.card_types_after(aggregate_card_type)
      if is_count
        next_types
      else
        # please keep sql for speed benefit.  ruby translation: next_types.select { |card_type| card_type.property_definitions.include?(target_property_definition) }
        sql = "SELECT * FROM #{CardType.table_name}
               WHERE #{CardType.table_name}.id IN (#{next_types.collect(&:id).join(',')}) AND
                     #{target_property_definition.id} IN
                      (SELECT property_definition_id FROM #{PropertyTypeMapping.table_name}
                       WHERE card_type_id = #{CardType.table_name}.id)"
        CardType.find_by_sql(sql)
      end
    end
  end

  # big performance improvement to aggregate computation background process by using sql here instead of tree_configuration.find_relationship method
  def find_relationship(tree_configuration, aggregate_card_type)
    relationship_sql = %{
      SELECT * FROM #{PropertyDefinition.table_name}
      WHERE tree_configuration_id = #{tree_configuration.id} AND
            valid_card_type_id = #{aggregate_card_type.id}
    }
    relationship = TreeRelationshipPropertyDefinition.find_by_sql(relationship_sql).first
  end

end
