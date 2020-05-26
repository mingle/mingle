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

class EnumeratedPropertyDefinition < PropertyDefinition
  include ListReorderingSupport::PropertyDefinitionSupport

  class ValueRestrictedException < StandardError
    attr_reader :project

    def initialize(bad_value, property_definition)
      @project = property_definition.project
      sentence = property_definition.allowed_values.bold.to_sentence
      allow_sentence = sentence.blank? ? ('NULL'.bold) : sentence
      super "#{bad_value.bold} is not a valid value for #{property_definition.name.bold}, which is restricted to #{allow_sentence}"
    end
  end

  has_many :enumeration_values, :order => :position, :foreign_key => 'property_definition_id', :after_add => :remove_duplicate_values
  before_destroy { |definition| definition.enumeration_values.each(&:destroy) }

  additionally_serialize :complete, [:property_value_details, :is_managed?], 'v2'

  def is_managed?
    true
  end

  def available_operators
    return Operator::Equals.name, Operator::NotEquals.name, Operator::LessThan.name, Operator::GreaterThan.name
  end

  def contains_value?(value)
    property_type.detect_existing(value.to_s, enumeration_values)
  end

  def contains_numeric_value?(value)
    enumeration_values.any? {|ev| value.to_f == ev.value.to_f }
  end

  def url_display_value(url_identifier)
    return nil unless url_identifier
    value = enumeration_values.detect { |ev| url_identifier.downcase == ev.value.downcase }
    value ? value.value : url_identifier
  end

  def create_value_if_not_exist(value, options = {:force => false})
    not_allowed_to_create = !options[:force] && !support_inline_creating?
    unless contains_value?(value) || not_allowed_to_create
      create_enumeration_value(:value => value)
    end
  end

  def create_enumeration_value(attributes)
    EnumerationValue.create(attributes.merge({:property_definition_id => id}))
  end

  def create_enumeration_value!(attributes)
    EnumerationValue.create!(attributes.merge({:property_definition_id => id}))
  end

  def comparison_value(view_identifier)
    return view_identifier if numeric?
    return if view_identifier.blank?
    if value = find_enumeration_value(view_identifier)
      value.position
    else
      raise ValueRestrictedException.new(view_identifier, self)
    end
  end

  #we compare enum property value by position, so it always is true
  def numeric_comparison_for?(value)
    true
  end

  def name_values
    enumeration_values.collect{|enum| [(is_numeric? ? project.to_num_maintain_precision(enum.value) : enum.value), enum.value] }
  end

  alias_method :card_filter_options, :name_values
  alias_method :lane_values, :name_values

  def label_values_for_charting
    enumeration_values.collect{|enum| enum.value }
  end

  def color(card)
    enum_value(card).try(:color)
  end

  def enum_value(card)
    card_value = value(card)
    enumeration_values.detect{|enum| enum.value == card_value}
  end

  def describe_type
    "Managed #{is_numeric ? 'number' : 'text'} list"
  end
  alias_method :type_description, :describe_type
  alias_method :property_values_description, :describe_type

  def validate_card(card)
    begin
      card_value = value(card)
      return if card_value.blank?
      if support_inline_creating?
        type_validation_errors = property_type.validate(value(card))
        if type_validation_errors.empty?
          unless enum_value(card)
            # TODO: This logic is duplicated in EnumerationValue#validate_does_not_start_with_opening_parenthesis_and_end_with_closing_parenthesis, which makes Jay sad.
            card.errors.add_to_base(attemped_to_create_plv(card_value)) if card_value.to_s.opens_and_closes_with_parentheses
          end
        else
          card.errors.add_to_base(type_validation_errors.to_sentence)
        end
      else
        return add_card_error(card, "does not have any defined values") if enumeration_values.empty?
        add_card_error(card, "is restricted to #{allowed_values.bold.to_sentence}") unless contains_value?(card_value)
      end
    rescue PropertyDefinition::InvalidValueException => e
      card.errors.add_to_base(e.message)
    end
  end

  def correct_value(value)
    unless value.blank?
      enumeration_value = property_type.detect_existing(value, enumeration_values)
      if enumeration_value
        value = enumeration_value.value
      elsif support_inline_creating?
        value = create_enumeration_value(:value => value).value
      end
    end
    value
  end

  def == other
    return false unless other
    return false unless [:name, :column_name, :ruby_name].all? { |expected_method| other.respond_to?(expected_method) }
    self.name == other.name && column_name == other.column_name && ruby_name == other.ruby_name
  end

  def numeric?
    is_numeric
  end

  def non_numeric_values
    enumeration_values.reject{|v| v.numeric?}
  end

  def property_values
    property_values_from_db(enumeration_values.collect(&:value))
  end

  def light_property_values
    property_values.collect do |property_value|
      OpenStruct.new(
        :display_value => property_value.display_value,
        :db_identifier => property_value.db_identifier,
        :url_identifier => property_value.url_identifier,
        :color => find_enumeration_value(property_value.db_identifier).color
      )
    end
  end

  def property_type
    is_numeric ? PropertyType::NumericType.new(project) : PropertyType::StringType.new
  end

  def support_inline_creating?
    return false if project.readonly_member?(User.current)
    !restricted? || project.admin?(User.current)
  end

  def support_filter?
    true
  end

  # optimization -- don't hit DB
  alias_method :enumeration_values_association, :enumeration_values
  def enumeration_values
    if is_numeric
      project.find_enumeration_values(self).sort_by{|enum| BigDecimal.new(enum.value)}
    else
      project.find_enumeration_values(self)
    end
  end

  alias_method :property_value_details, :enumeration_values

  def find_enumeration_value(value)
    property_type.detect_existing(value, enumeration_values, true)
  end

  alias_method :values, :enumeration_values
  alias_method :lockable?, :finite_valued?

  def sort_position(db_identifier)
    if enum_value = find_enumeration_value(db_identifier)
      enum_value.position
    else
      -1
    end
  end

  def allowed_values
    enumeration_values.collect(&:value)
  end

  def sort_value(property_value)
    enum_value = enumeration_values.find{ |enum_value| enum_value.value == property_value.display_value} if property_value
    enum_value.position if enum_value
  end

  def lane_identifier(enumeration_value)
    return ' ' if enumeration_value.blank?
    enumeration_value = enumeration_values.detect {|v| v.value == enumeration_value }
    enumeration_value.try(:value)
  end

  def rename_value(old_name, new_name)
    if enumeration_value = find_enumeration_value(old_name)
      enumeration_value.value = new_name
      enumeration_value.nature_reorder_disabled = true
      enumeration_value.save
    else
      enumeration_value = EnumerationValue.new(:value => old_name)
      enumeration_value.errors.add_to_base("Cannot rename #{old_name} since it is non-existent.")
    end
      enumeration_value
  end

  private

  # see technical task 4809 for an understanding of this method
  def remove_duplicate_values(enumeration_value)
    self.enumeration_values_association.uniq!
  end

  def add_card_error(card, message)
    card.errors.add_to_base "#{self.name.bold} #{message}"
  end
end
