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

class EnumerationValue < ActiveRecord::Base
  include ListReorderingSupport::EnumerationValueSupport, SqlHelper
  belongs_to :property_definition, :class_name => "EnumeratedPropertyDefinition", :foreign_key => "property_definition_id"
  strip_on_write
  use_database_limits_for_all_attributes
  acts_as_list :scope => :property_definition
  validates_presence_of :value
  validates_uniqueness_of :value, :scope  => :property_definition_id, :case_sensitive => false, :if => Proc.new { |enum_value|
    !enum_value.property_definition.numeric?
  }

  attr_accessor :nature_reorder_disabled

  before_create :assign_color
  after_save :update_denormalized_data_on_value_changed

  before_destroy :ensure_not_in_use
  before_destroy :clean_history_subscriptions
  before_destroy :remove_value_from_card_defaults


  ILLEGAL_VALUES = [PropertyValue::IGNORED_IDENTIFIER, Transition::USER_INPUT_REQUIRED, Transition::USER_INPUT_OPTIONAL]

  serializes_as :complete => [:id, :value, :color, :position],
                :compact => [:value],
                :element_name => 'property_value'

  def self.definition_class
    EnumeratedPropertyDefinition
  end

  alias_method_chain :save, :reorder_values
  alias_method_chain :save!, :reorder_values

  after_save :clear_enumeration_value_cache
  before_save :format_numeric_value_when_it_is_out_of_precision

  before_destroy :update_aggregates

  class << self

    def not_set
      OpenStruct.new(:value => ' ', :errors => [])
    end

    def find_or_construct(options)
      find_existing(options) || EnumerationValue.create(options)
    end

    def find_existing(options)
      if options[:value].blank?
        EnumerationValue.not_set
      else
        property_definition = PropertyDefinition.find(options[:property_definition_id])
        property_definition.find_enumeration_value(options[:value])
      end
    end

    def exists_with_check_by_name?(id_or_condition = {})
      return false if id_or_condition.blank?
      return exists_without_check_by_name?(id_or_condition) unless String === id_or_condition
      self.count(:conditions => ['UPPER(enumeration_values.value) = UPPER(?)', id_or_condition.trim]) > 0
    end

    alias_method_chain :exists?, :check_by_name
  end

  def assign_color
    self.color = Color.random(self.property_definition.enumeration_values.collect(&:color)) if color.blank?
  end

  def project
    Project.current
  end

  def property_definition
    project.enum_property_definitions_with_hidden.detect{|pd| pd.id == self.property_definition_id}
  end
  memoize :property_definition

  def save_with_update_aggregates(validate = true)
    update_aggregates
    save_without_update_aggregates(validate)
  end
  alias_method_chain :save, :update_aggregates

  def used_on?(card)
    value == property_definition.value(card)
  end

  def update_card(card)
    property_definition.update_card(card, value)
  end

  def name
    value
  end

  def project_variables
    property_definition.project_variables.select { |pv| pv.value.ignore_case_equal?(self.value) }
  end

  def card_list_views
    project.card_list_views.select{|view| view.uses_property_value?(property_definition.name, self.value)}
  end

  def value=(new_value)
    @old_value = value  # used for post-save re-ordering
    write_attribute(:value, new_value)
  end

  def as_property_value
    PropertyValue.create_from_db_identifier(property_definition, value)
  end

  # TODO we need to remove it after numeric property definition
  def numeric?
    value.numeric?
  end

  def validate
    validation_errors = property_definition.property_type.validate(value)
    validation_errors.each {|error| errors.add(:value, error)}
    validate_unique_numeric_value if property_definition.numeric? && value.numeric?
    validate_does_not_start_with_opening_parenthesis_and_end_with_closing_parenthesis unless property_definition.numeric?
  end

  protected

  def update_denormalized_data_on_value_changed
    if value_changed?
      old_value, new_value = value_change
      return if old_value.blank?

      update_plv_values(old_value, new_value)
      update_cards_on_value_change(old_value, new_value)
      update_history_subscription(old_value, new_value)
      update_aggregate_condition(old_value, new_value)
    end
  end

  def clean_history_subscriptions
    card_list_views.each(&:destroy)
    project.history_subscriptions.each do |subscription|
      filter_params = subscription.to_history_filter_params
      involved = if filter_params.involved_filter_properties
        filter_params.involved_filter_properties.any? {|prop, value| property_definition.name?(prop) && value.ignore_case_equal?(self.value)}
      end
      acquired = if filter_params.acquired_filter_properties
        filter_params.acquired_filter_properties.any? {|prop, value| property_definition.name?(prop) && value.ignore_case_equal?(self.value)}
      end

      subscription.destroy if involved || acquired
    end
  end

  def ensure_not_in_use
    raise ValueStillInUseError.new("EnumerationValue #{value.bold} is still in use.") unless self.as_property_value.unused?
  end

  def clear_enumeration_value_cache
    project.clear_enumeration_values_cache
  end

  def remove_value_from_card_defaults
    property_definition.card_types.each do |card_type|
      card_defaults = card_type.card_defaults
      card_defaults.actions.select { |action| action.property_definition == property_definition && action.value == self.value}.each(&:destroy)
      card_defaults.save!
    end
  end

  private


  def validate_unique_numeric_value
    # This method is modeled after ActiveRecord::Validations::ClassMethods#validates_uniqueness_of
    table_name = EnumerationValue.table_name
    condition_sql = "#{table_name}.property_definition_id = ?"
    condition_params = [property_definition_id]
    if value.blank?
      condition_sql << " AND #{table_name}.value IS NULL"
    else
      condition_sql << " AND #{as_number "#{table_name}.value"} = ?"
      condition_params << property_definition.project.to_num(value.to_f)
    end
    unless new_record?
      condition_sql << " AND #{table_name}.#{EnumerationValue.primary_key} <> ?"
      condition_params << id
    end
    if EnumerationValue.find(:first, :conditions => [condition_sql, *condition_params])
      errors.add(:value, 'has already been taken')
    end
  end

  def update_history_subscription(old_value, new_value)
    Project.current.history_subscriptions.each do |subscription|
      subscription.rename_property_value(property_definition.name, old_value, new_value)
      subscription.save!
    end
  end

  def update_cards_on_value_change(old_value, new_value)
    if Card.columns.any?{|col| col.name == property_definition.column_name}
      project.card_schema.rename_column_value(property_definition.column_name, old_value, new_value)
      Change::rename_change_value project.id, property_definition.name, old_value, new_value

      sql = SqlHelper.sanitize_sql("UPDATE transition_prerequisites SET value = ? WHERE value = ? and property_definition_id = ?",
          new_value, old_value, property_definition.id)
      ActiveRecord::Base.connection.execute(sql)

      sql = SqlHelper.sanitize_sql("UPDATE transition_actions SET value = ? WHERE value = ? and target_id = ?",
          new_value, old_value, property_definition.id)
      ActiveRecord::Base.connection.execute(sql)

      project.card_list_views.each do |view|
        view.rename_property_value(property_definition.name, old_value, new_value) && view.save!
      end

      FullTextSearch.index_cards(project)
    end
  end

  def update_aggregates
    project.aggregate_property_definitions_with_hidden.each do |agg|
      agg.update_cards if agg.uses_property_value?(self.property_definition.name, self.value)
    end
  end

  def update_aggregate_condition(old_value, new_value)
    project.aggregate_property_definitions_with_hidden.each do |aggregate_definition|
      aggregate_definition.rename_dependent_enumeration(property_definition, old_value, new_value)
      aggregate_definition.save_without_validation!
    end
  end

  def update_plv_values(old_value, new_value)
    project.project_variables.each { |plv| plv.rename_enum_value_usage(self.property_definition, old_value, new_value) }
  end

  def format_numeric_value_when_it_is_out_of_precision
    if property_definition.numeric?
        self.value =  property_definition.property_type.sanitize_db_identifier(value, property_definition)
    end
  end

  def validate_does_not_start_with_opening_parenthesis_and_end_with_closing_parenthesis
    errors.add(:value, "cannot both start with '(' and end with ')'") if value.to_s.opens_and_closes_with_parentheses
  end
end

class ValueStillInUseError < StandardError
end
