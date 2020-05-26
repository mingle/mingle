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

class CardTypeDefinition
  include ListReorderingSupport::PropertyDefinitionSupport
  include PropertyDefinitionSupport
  include PluralizationSupport
  unmemoize_all #since we use this as singlton

  PROPERTY_NAME = 'Type'

  INSTANCE = CardTypeDefinition.new

  def initialize(project=nil)
    @project = project
  end

  alias_method :id, :object_id

  def tooltip
    name
  end

  def can_use_with_card_type?(card_type)
    true
  end

  def is_predefined
    true
  end

  def position
    -1
  end

  def transition_only_for_updating_card?(card=nil)
    false
  end
  def transition_only?
    false
  end

  def property_type
    PropertyType::StringType.new
  end

  def create_value_if_not_exist(value)
    unless values.exists?(value)
      card_type = project.card_types.create :name => value, :nature_reorder_disabled => true
      card_type.property_definitions = project.cards.find_all_by_card_type_name(card_type.name).inject([]) do |result, card|
        result << project.property_definitions.select{|prop_def| prop_def.value?(card) }
      end.flatten.uniq
      card_type.save
    end
  end

  def field_name
    name
  end

  def value(card)
    card.card_type_name
  end

  def describe_type
    PROPERTY_NAME
  end
  alias_method :type_description, :describe_type

  def serialize_lightweight_attributes_to(serializer)
    serializer.property_definition do
      serializer.name name
      serializer.description 'Type'
      serializer.type_description type_description
    end
  end

  #For now, card type cannot be changed in a transition - so transition_only is false
  def transition_only
    false
  end

  def comparison_value(view_identifier)
    return if view_identifier.blank?
    if value = find_card_type(view_identifier)
      value.position
    else
      raise EnumeratedPropertyDefinition::ValueRestrictedException.new(view_identifier, self)
    end
  end

  def sort_position(db_identifier)
    if db_identifier && value = find_card_type(db_identifier)
      value.position
    else
      -1
    end
  end

  def allowed_values
    values.collect(&:value)
  end

  def contains_value?(value)
    value = value.to_s
    values.any? {|ct| value.downcase == ct.value.downcase }
  end

  def url_display_value(url_identifier)
    return nil unless url_identifier
    type = values.detect {|ct| url_identifier.downcase == ct.value.downcase }
    type ? type.name : url_identifier
  end

  def color(card)
    card.card_type.color
  end

  def groupable?
    true
  end

  def colorable?
    true
  end

  def global?
    true
  end

  def nullable?
    false
  end

  def calculated?
    false
  end

  def formulaic?
    false
  end

  def excel_importable?
    true
  end

  def update_card(card, value, options={})
    card.card_type_name = value
  end

  def name
    PROPERTY_NAME
  end

  def column_name
    'card_type_name'
  end

  def column_type
    :string
  end

  alias_method :quoted_column_name, :column_name
  alias_method :ruby_name, :column_name
  alias_method :html_id, :column_name

  def name?(property_name)
    self.name.ignore_case_equal? property_name.to_s
  end

  def project
    @project || Project.current
  end

  def card_type_names
    project.card_types.collect(&:name)
  end

  def card_type_options
    project.card_types.collect{|card_type| [card_type.name, card_type.name]}
  end

  def values
    project.card_types
  end

  def property_values
    property_values_from_db(project.card_types.collect(&:name))
  end

  def tree_special?
    false
  end

  def tree_configuration_id
    nil
  end

  def project_variables
    []
  end

  alias_method :card_filter_options, :card_type_options
  alias_method :name_values, :card_type_options
  alias_method :lane_values, :card_type_options

  def numeric_comparison_for?(value)
    true
  end

  def support_inline_creating?
    false
  end

  def support_filter?
    false
  end

  def db_identifier(card)
    card.card_type_name
  end

  def hidden?
    false
  end

  def ==(o)
    o.is_a?(CardTypeDefinition) && self.project == o.project
  end
  alias :equal? :==
  alias :eql? :==

  def hash
    project.id
  end

  def lane_identifier(card_type_name)
    card_type_name
  end

  def errors
    @errors ||= ActiveRecord::Errors.new(CardType.new)
  end

  def rename_value(old_name, new_name)
    if card_type = find_card_type(old_name)
      card_type.name = new_name
      card_type.save
    else
      card_type = CardType.new :name => old_name
      card_type.errors.add_to_base("Cannot rename #{old_name} since it is non-existent.")
    end
    card_type
  end

  def mql_select_column_value(v)
    v
  end

  private
  def find_card_type(card_type_name)
    self.values.detect{|ct| ct.name.downcase.trim == card_type_name.to_s.downcase.trim }
  end

end
