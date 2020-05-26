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

class PropertyValue
  include SqlHelper, API::XMLSerializer, CardView::GridHeader
  NOT_SET = '(not set)'
  NOT_SET_VALUE = ''
  NOT_SET_VALUE_PAIR = [NOT_SET, NOT_SET_VALUE]
  SET = '(set)'
  SET_VALUE = '(set)'
  SET_VALUE_PAIR = [SET, SET_VALUE]
  IGNORED_IDENTIFIER = ':ignore'
  ANY = '(any)'
  ANY_VALUE_PAIR = [ANY, IGNORED_IDENTIFIER]
  NO_CHANGE = '(no change)'
  NO_CHANGE_PAIR = [NO_CHANGE, IGNORED_IDENTIFIER]
  ANY_CHANGE = '(any change)'
  ANY_CHANGE_PAIR = [ANY_CHANGE, ANY_CHANGE]
  NOT_SET_LANE_IDENTIFIER = ' '

  attr_reader :property_definition, :property_type
  serializes_as :name, :value

  def to_xml_with_alternate_root_element_name(options = {})
    to_xml_without_alternate_root_element_name(options.merge(:element_name => 'property', :type_description => @property_definition.type_description, :attribute_options => {:hidden => hidden?}))
  end
  alias_method_chain :to_xml, :alternate_root_element_name

  class << self
    def create_from_db_identifier(prop_def, db_identifier, stale=false)
      db_identifier = convert_to_nullable_string(db_identifier)
      if plv=find_plv_by_name(prop_def, db_identifier)
        VariableBinding.find_by_property_definition_id_and_project_variable_id(prop_def.id, plv.id)
      else
        PropertyValue.new(prop_def, db_identifier, stale)
      end
    end

    def create_from_url_identifier(prop_def, url_identifier)
      url_identifier = convert_to_nullable_string(url_identifier)
      if plv = find_plv_by_name(prop_def, url_identifier)
        VariableBinding.find_by_property_definition_id_and_project_variable_id(prop_def.id, plv.id)
      else
        begin
          db_identifier = url_identifier == NOT_SET ? nil : prop_def.property_type.url_to_db_identifier(url_identifier)
        rescue
          db_identifier = url_identifier
        end
        create_from_db_identifier(prop_def, db_identifier)
      end
    end

    def not_set_instance(prop_def)
      create_from_db_identifier(prop_def, nil)
    end

    private

    def find_plv_by_name(prop_def, name)
      if ProjectVariable.is_a_plv_name?(name) && prop_def.respond_to?(:project_variables)
        prop_def.project_variables.detect{ |plv| plv.display_name.ignore_case_equal?(name) }
      end
    end

    def convert_to_nullable_string(value)
      return nil if value.blank?
      value.to_s
    end
  end

  def initialize(property_def, db_identifier, stale = false)
    @property_definition = property_def
    @property_type = property_def.property_type
    @raw_db_identifier = db_identifier
    @stale = stale
  end

  def db_identifier
    @db_identifier ||= preserved_identifier?(@raw_db_identifier) ? @raw_db_identifier : @property_type.sanitize_db_identifier(@raw_db_identifier, @property_definition)
  end

  def project
    @property_definition.project
  end

  def derefer
    self
  end

  def stale?
    @stale
  end

  def value_equal?(another)
    self == another
  end

  def ==(another)
    if another.is_a?(VariableBinding)
      @property_type.equal_values?(self, another.property_value)
    else
      @property_type.equal_values?(self, another)
    end
  end

  def matches_transition_prerequisite_or_action?(prerequisite_or_action)
    prerequisite_or_action.property_definition.id == property_definition.id && prerequisite_or_action.project_variable.nil? && prerequisite_or_action.value == db_identifier
  end

  def to_s
    "#{property_definition.name}##{db_identifier}"
  end

  def field_name
    property_definition.field_name
  end

  def field_value
    if property_definition.date? && !db_identifier.nil?
      @property_type.display_value_for_db_identifier(db_identifier)
    else
      db_identifier
    end
  end

  def association_type?
    PropertyType.association_type?(@property_type)
  end

  def display_value
    return NOT_SET unless db_identifier
    return ANY_CHANGE if db_identifier == ANY_CHANGE
    @property_type.display_value_for_db_identifier(db_identifier)
  end

  def grid_view_display_value(abbreviated = false)
    tree_relationship_display_value(abbreviated) || display_value
  end

  def abbreviated_grid_view_display_value
    grid_view_display_value(true)
  end

  def tree_relationship_display_value(abbreviated)
    dbid = db_identifier.to_i
    return unless @property_definition.respond_to?(:expanded_display_values)
    abbreviated ? @property_definition.abbreviated_display_values[dbid] : @property_definition.expanded_display_values[dbid]
  end

  def charting_value
    if PropertyType::CardType === @property_type
      return @property_type.display_value_for_db_identifier(db_identifier)
    end

    @property_type.format_value_for_card_query(url_identifier)
  end

  def computed_value
    property_definition.property_type.find_object(db_identifier)
  end
  alias_method :value, :computed_value

  # use this value to sort a property_value list, see PropertyDefinitionSupport#sort
  def sort_position
    property_definition.sort_position(db_identifier)
  end

  # looks like we use this value to select a value in a sorted list on UI
  def sort_value
    return NOT_SET unless db_identifier
    return db_identifier if has_special_value?

    property_definition.sort_value(self)
  end

  def display_value_with_stale_state
    stale? ? "* #{display_value}" : display_value
  end

  def lane_identifier
    @property_type.db_to_lane_identifier(db_identifier) || NOT_SET_LANE_IDENTIFIER
  end

  def url_identifier
    @property_type.db_to_url_identifier(db_identifier)
  end

  #looks like no one use this, and this is not sql safe
  def sql_safe_db_identifier
    not_set? ? NOT_SET : db_identifier
  end

  def export_value
    @property_type.export_value(db_identifier)
  end

  def not_set?
    db_identifier.nil?
  end

  def set?
    db_identifier
  end

  def to_not_set
    self.class.not_set_instance(@property_definition)
  end

  def ignored?
    db_identifier == IGNORED_IDENTIFIER
  end

  def card_count(query=CardQuery.empty_query)
    property_definition.card_count_for(db_identifier, query)
  end

  def matching_cards_sql
    not_set? ? "#{property_definition.quoted_column_name} IS NULL" : sanitize_sql("#{property_definition.quoted_column_name} = ?", db_identifier)
  end

  def transition_count
    property_definition.project.transitions.select{|transition| transition.uses?(self) }.size
  end

  def unused?
    transition_count == 0 and card_count == 0
  end

  def hidden?
    property_definition.hidden?
  end

  def name
    property_definition.name
  end

  def column_name
    property_definition.column_name
  end

  def tree_name
    if property_definition.tree_configuration_id
      if tree_config = project.tree_configurations.detect{|tc| tc.id == property_definition.tree_configuration_id}
        tree_config.name
      end
    end
  end

  def db_value_pair
    [display_value, db_identifier]
  end

  def assigned_to?(card)
    card.property_value(property_definition) == self
  end

  def assign_to(card, options={})
    property_definition.update_card(card, db_identifier, options)
  end

  def has_special_value?
    preserved_identifier?(db_identifier)
  end

  def card_type_value?
    property_definition.is_a? CardTypeDefinition
  end

  def has_current_user_special_value?
    @property_type.respond_to?(:is_current_user?) && @property_type.is_current_user?(db_identifier)
  end

  def transition_only?
    property_definition.transition_only?
  end

  def card_usage
    PropertyUsage.new(self, card_count)
  end

  def card_defaults_usage
    PropertyUsage::CardDefaults.new(self, card_defaults_used)
  end

  private

  def card_defaults_used
    query = %Q{
      SELECT executor_id
      FROM #{TransitionAction.quoted_table_name} ta
        INNER JOIN #{PropertyDefinition.quoted_table_name} pd ON pd.id=ta.target_id
      WHERE ta.executor_type='CardDefaults' AND ta.value='#{value.id}' AND pd.project_id=#{property_definition.project_id} AND pd.id=#{property_definition.id}
      }

    card_defaults_ids = select_values(query)
    card_defaults_ids.collect { |id| CardDefaults.find_by_id(id) }
  end

  def preserved_identifier?(identifier)
    ([IGNORED_IDENTIFIER, Transition::USER_INPUT_REQUIRED, Transition::USER_INPUT_OPTIONAL] + @property_type.reserved_identifiers).include?(identifier)
  end
end

class PropertyValueSet

  def initialize(property_definition)
    @property_definition = property_definition
  end

  def property_definition
    @property_definition
  end

  def name
    property_definition.name
  end

  def display_value
    PropertyValue::SET
  end

  def sort_value
    PropertyValue::SET
  end

  def hidden?
    property_definition.hidden?
  end
end
