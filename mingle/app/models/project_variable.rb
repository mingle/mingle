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

class  ProjectVariable < ActiveRecord::Base
  STRING_DATA_TYPE = 'StringType'
  DEFAULT_DATA_TYPE = STRING_DATA_TYPE
  USER_DATA_TYPE = 'UserType'
  NUMERIC_DATA_TYPE = 'NumericType'
  DATE_DATA_TYPE = 'DateType'
  CARD_DATA_TYPE = 'CardType'
  DATA_TYPE_DESCRIPTIONS = {STRING_DATA_TYPE => 'Text',
                            NUMERIC_DATA_TYPE => 'Numeric',
                            USER_DATA_TYPE => 'Selected from team list',
                            DATE_DATA_TYPE => 'Date',
                            CARD_DATA_TYPE => 'Card'}
  DATA_TYPES = DATA_TYPE_DESCRIPTIONS.keys

  belongs_to :project
  belongs_to :card_type, :class_name => '::CardType'
  named_scope :order_by_name, :order => 'lower(name)'

  has_many :property_definitions, :through => :variable_bindings

  validates_presence_of :name, :data_type
  validates_uniqueness_of :name, :case_sensitive => false, :scope => [:project_id]
  before_validation :set_default_data_type_if_it_is_blank_and_trim_name_value
  before_destroy :destroy_transitions_that_use_this_project_variable
  # TODO put has many variable_bindings after destroy transition, should we use has many transtions instead before destroy ?
  has_many :variable_bindings, :dependent => :destroy
  before_destroy :destroy_card_list_views
  before_save :modify_value_to_match_project_precision_for_numeric_data_type
  after_save :create_new_enumeration_values_if_not_exist, :repair_transitions, :update_aggregates
  after_update :clean_transitions
  after_update :clean_bindings
  after_update :clean_saved_views

  use_database_limits_for_all_attributes

  class << self
    def user_ids
      ThreadLocalCache.get("ProjectVariable.user_ids") do
        query = "SELECT DISTINCT value FROM #{quoted_table_name} WHERE data_type = '#{ProjectVariable::USER_DATA_TYPE}'"
        connection.select_values(query).compact.map(&:to_i)
      end
    end

    def variables_that_use_user(project, team_member)
      project.project_variables.select{|project_variable| project_variable.uses_team_member?(team_member) }
    end

    def warning_messages_of(project, variable_name, prop_def)
      return if !prop_def.respond_to?(:enumeration_values) || variable_name.blank?
      variable = PropertyValue.create_from_url_identifier(prop_def, variable_name)
      if value = prop_def.property_values.detect{|value| value == variable}
        "Because the project variable name matches an existing value #{value.url_identifier.bold} for #{prop_def.name.bold}, it will always be used when setting this property value using transitions."
      end
    end

    def extract_plv_name(value)
      $1 if value =~ /^\((.*)\)$/ && !Project::RESERVED_IDENTIFIERS.ignore_case_include?(value)
    end

    def is_a_plv_name?(value)
      true if extract_plv_name(value)
    end

    def display_name(name)
      name.blank? ? '' : "(#{name})"
    end

    def is_defined?(project, plv_name)
      project.project_variables.collect(&:name).ignore_case_include?(plv_name)
    end

    def find_plv_in_current_project(plv_name)
      Project.current.project_variables.find(:first, :conditions => ["LOWER(name) = ?", plv_name.downcase] )
    end
  end

  def set_default_data_type_if_it_is_blank_and_trim_name_value
    self.data_type = self.data_type
    self.name = self.name.trim unless self.name.blank?
    self.value = self.value.to_s.trim unless self.not_set?
  end

  def property_definition_ids
    self.variable_bindings.reject(&:should_destroy?).collect(&:property_definition_id)
  end

  def property_definition_ids=(ids)
    existing_property_definition_ids = self.variable_bindings.collect(&:property_definition_id)

    ids = [ids].flatten.collect(&:to_i)
    property_definitions_to_be_deleted = existing_property_definition_ids - (ids || [])
    property_definitions_to_be_created = (ids || []) - existing_property_definition_ids

    variable_bindings.each do |binding|
      binding.should_destroy = true if property_definitions_to_be_deleted.include?(binding.property_definition_id)
    end

    property_definitions_to_be_created.collect do |prop_def_id|
      variable_bindings.build(:property_definition_id => prop_def_id)
    end
  end

  def associated_with?(prop_def)
    return false unless prop_def.is_a?(PropertyDefinition) # could be CardQuery::CardIdColumn::CardIdPropertyDefinition
    association_count_sql = <<-SQL
      SELECT COUNT(*) FROM
      #{ProjectVariable.quoted_table_name} plv
      JOIN #{VariableBinding.quoted_table_name} vb ON (vb.project_variable_id = plv.id AND vb.property_definition_id = ?)
      WHERE plv.id = ?
      AND plv.project_id = ?
    SQL

    sanitized_sql = SqlHelper.sanitize_sql(association_count_sql, prop_def.id, self.id, self.project_id)
    ActiveRecord::Base.connection.select_value(sanitized_sql).to_i >= 1
  end

  def transitions_need_to_be_deleted_on_update
    variable_bindings.select(&:should_destroy?).collect do |binding|
      binding.transitions
    end.flatten
  end

  def team_views_needing_deletion_on_update
    data_type_changed? ? card_list_views : views_on_bindings_matching(&:should_destroy?).select(&:team?)
  end

  def views_needing_deletion_on_update
    data_type_changed? ? card_list_views : views_on_bindings_matching(&:should_destroy?)
  end

  def clean_bindings
    variable_bindings.each do |binding|
      binding.destroy if binding.should_destroy?
    end
  end

  def clean_transitions
    transitions_need_to_be_deleted_on_update.each(&:destroy)
  end

  def clean_saved_views
    views_needing_deletion_on_update.each(&:destroy)
  end

  def property_definitions=(property_definitions)
    self.property_definition_ids = (property_definitions || []).collect(&:id)
  end

  def destroy_transitions_that_use_this_project_variable
    used_by_transitions.each(&:destroy)
  end

  def destroy_card_list_views
    card_list_views.each(&:destroy)
  end

  def name=(new_name)
    if name && name != new_name && record_exists?
      project.card_list_views.each { |view| view.rename_project_variable(name, new_name) }
      update_aggregate_condition_on_name_change(new_name)
    end
    write_attribute(:name, new_name)
  end

  def update_aggregate_condition_on_name_change(new_name)
    project.aggregate_property_definitions_with_hidden.each do |aggregate_definition|
      aggregate_definition.rename_dependent_project_variable(name, new_name)
      aggregate_definition.save_without_validation!
    end
  end

  def card_list_view_usage_count
    sql = SqlHelper.sanitize_sql(%Q{
      SELECT count(*)
        FROM card_list_views
       WHERE project_id = ?
         AND canonical_string LIKE ?
    }, project.id, "%filters=%#{display_name.downcase}%")
    CardListView.count_by_sql sql
  end

  def transition_usage_count
    sql = SqlHelper.sanitize_sql(%Q{
      SELECT COUNT(DISTINCT id)
        FROM (
          SELECT t.id as id
            FROM transitions t, transition_prerequisites tp
           WHERE t.project_id = ?
             AND tp.transition_id = t.id
             AND tp.project_variable_id = ?

          UNION ALL

          SELECT t.id as id
            FROM transitions t, transition_actions ta, variable_bindings vb
           WHERE t.project_id = ?
             AND ta.executor_id = t.id
             AND ta.executor_type = 'Transition'
             AND ta.variable_binding_id = vb.id
             AND vb.project_variable_id = ?
        ) usages
    }, project.id, id, project.id, id)
    Transition.count_by_sql sql
  end

  def card_list_views
    project.card_list_views.select{ |view| view.uses_plv?(self) }
  end

  def unassociated_property_warning(property_definition)
    unless associated_with?(property_definition)
      if property_definition.nil?
        "Project variable #{display_name.bold} is not valid for the property."
      else
        "Project variable #{display_name.bold} is not valid for the property #{property_definition.name.bold}."
      end
    end
  end

  def validate
    errors.add :name, "#{self.name.bold} is a reserved property value." if Project::RESERVED_IDENTIFIERS.any?{ |id| remove_parenthesis(id).ignore_case_equal?(self.name) }
    return errors.add(:data_type, 'must be selected') unless DATA_TYPES.include?(self.data_type)

    if (self.data_type == STRING_DATA_TYPE) && (self.value =~ Project::RESERVED_VALUE_IDENTIFER_REGEX)
      errors.add :value, "cannot both start with '(' and end with ')'"
    end

    invalid_props = self.variable_bindings.reject(&:frozen?).reject(&:should_destroy?).collect(&:property_definition) - self.all_available_property_definitions

    unless invalid_props.compact.blank?
      errors.add(:property_definitions, "#{invalid_props.collect(&:name).bold.to_sentence} cannot be applied to type '#{describe_type}'")
    end

    data_type_instance.validate(self.value).each { |value_error| errors.add :value, value_error }
  end

  def used_by_transitions
    project.transitions.select{|transition| transition.uses_project_variable?(self)}
  end

  def in_use?
    !(card_list_views.empty? && used_by_transitions.empty?)
  end

  def clear_team_member(user)
    update_attributes(:value => nil) if uses_team_member?(user)
  end

  def rename_enum_value_usage(property_definition, old_value, new_value)
    return unless uses_enumeration_value?(property_definition, old_value)
    if (self.property_definitions.size == 1)
      self.update_attributes(:value => new_value)
    else
      binding_to_delete = self.variable_bindings.detect { |b| b.uses_enumeration_value?(property_definition, value) }
      system_generated_variable = project.project_variables.create!(:name => generate_unique_name(name), :data_type => data_type, :value => new_value)
      new_binding = VariableBinding.create(:property_definition => binding_to_delete.property_definition, :project_variable => system_generated_variable)
      used_by_transitions.select { |t| t.uses_project_variable?(self) }.each { |t| t.change_project_variable_usage(self, system_generated_variable, new_binding) }

      binding_to_delete.destroy
      project.project_variables.reload
    end
  end

  def smooth_update?
    (team_views_needing_deletion_on_update + transitions_need_to_be_deleted_on_update).empty?
  end

  def uses_enumeration_value?(property_definition, value)
    possible_enum_type = (self.data_type == ProjectVariable::STRING_DATA_TYPE || self.data_type == ProjectVariable::NUMERIC_DATA_TYPE)
    return unless possible_enum_type
    self.variable_bindings.any? { |b| b.uses_enumeration_value?(property_definition, value) }
  end

  def uses_card?(card)
    return if card.new_record?
    data_type == ProjectVariable::CARD_DATA_TYPE && value.to_i == card.id.to_i
  end

  def uses_team_member?(user)
    user_type? && self.value.to_i == user.id
  end

  def all_available_property_definitions
    data_type_instance.all_available_property_definitions.smart_sort_by(&:name)
  end

  def data_type_instance
    if(card_data_type?)
      ProjectVariable::CardType.new(self.project, card_type)
    else
      "ProjectVariable::#{self.data_type}".constantize.new(self.project)
    end
  end

  alias_method :property_type, :data_type_instance

  def describe_type
    DATA_TYPE_DESCRIPTIONS[data_type]
  end

  def data_type
    super.blank? ? DEFAULT_DATA_TYPE : super
  end

  def value_field_container
    data_type_instance.value_field_container
  end

  def display_value
    return PropertyValue::NOT_SET if self.not_set?
    data_type_instance.display_value_for_db_identifier(self.value)
  rescue Exception => e
    self.value = self.new_record? ? '' : self.project.project_variables.find(self.id).value
  end

  def charting_value
    return nil if not_set?
    data_type_instance.format_value_for_card_query(card_query_value)
  end

  def display_name
    self.class.display_name(name)
  end

  def display_card_link?
    ProjectVariable::CARD_DATA_TYPE == data_type && !self.not_set?
  end

  def create_new_enumeration_values_if_not_exist
    self.variable_bindings.collect(&:property_definition).each do |property_definition|
      property_definition.create_value_if_not_exist(value, :force => true) if property_definition.respond_to?(:create_value_if_not_exist)
    end
  end

  def card_query_value
    data_type_instance.db_to_url_identifier(self.value)
  end

  def association_type?
    PropertyType.association_type?(data_type_instance)
  end

  def serialize_lightweight_attributes_to(serializer)
    serializer.project_variable do
      serializer.name name
      serializer.display_value display_value
    end
  end

  def not_set?
    value.blank?
  end

  class UserType < PropertyType::UserType
    def initialize(project)
      super
      @project = project
    end

    def all_available_property_definitions
      @project.user_property_definitions_with_hidden
    end

    def validate(value)
      return [] if value.blank?
      @project.user_prop_values.any? {|user| user.id == value.to_i } ? [] : ["must select a team member"]
    end

    def select_options
      [].unshift([PropertyValue::NOT_SET, nil])
    end

    def value_field_container
      'user_type_value_field'
    end
  end

  class StringType < PropertyType::StringType
    def initialize(project)
      @project = project
    end

    def all_available_property_definitions
      @project.text_list_property_definitions_with_hidden + @project.text_free_property_definitions_with_hidden
    end

    def validate(value)
      []
    end

    def value_field_container
      'value_field'
    end
  end

  class DateType < PropertyType::DateType

    def all_available_property_definitions
      @project.date_property_definitions_with_hidden
    end

    def validate(value)
      return [validation_error_message(value)] if project_today_identifiers?(value.to_s)
      find_object(value)
      []
    rescue PropertyDefinition::InvalidValueException => e
      [e.message]
    end

    def value_field_container
      'date_type_value_field'
    end
  end

  class NumericType < PropertyType::NumericType
    def all_available_property_definitions
      @project.numeric_list_property_definitions_with_hidden + @project.numeric_free_property_definitions_with_hidden
    end

    def value_field_container
      'value_field'
    end
  end

  class CardType < PropertyType::CardType

    def initialize(project, card_type)
      @project = project
      @card_type = card_type
    end

    def all_available_property_definitions
      relationship_properties = @card_type.tree_relationship_properties if @card_type
      (relationship_properties || []) + @project.card_relationship_property_definitions_with_hidden
    end

    def value_field_container
      'card_type_value_field'
    end

    def validate(value)
      []
    end
  end

  def destroy
    # Overriding destroy to simulate a before_destroy because somehow Rails's destroy will remove associations that are :destroy => :dependent
    # (such as variable_bindings) before the before_destroy hook executes.
    update_aggregates
    super
  end
  def data_type_description
    if card_data_type?
      return card_type.nil? ? 'Card' : "Card: #{card_type.name}"
    end
    describe_type
  end

  def property_definition_names
    property_definitions.map(&:name)
  end

  def export_value
    card_data_type? ? data_type_instance.display_value_for_db_identifier(self.value) : self.value
  end

  private

  def views_on_bindings_matching(&block)
    variable_bindings.select(&block).map(&:card_list_views).flatten.uniq
  end

  def modify_value_to_match_project_precision_for_numeric_data_type
    self.value = project.to_num_maintain_precision(self.value) if data_type == NUMERIC_DATA_TYPE
  end

  def generate_unique_name(name, suffix = 1)
    sql = SqlHelper.sanitize_sql("SELECT LOWER(name) FROM project_variables WHERE project_id = ?", project.id)
    @existing_names ||= ActiveRecord::Base.connection.select_values(sql)
    return @existing_names.include?("#{name} #{suffix}") ? generate_uniuqe_name(name, suffix.succ) : "#{name} #{suffix}"
  end

  def remove_parenthesis(obj)
    obj.to_s.gsub(/\(|\)/, '')
  end

  def user_type?
    data_type == USER_DATA_TYPE
  end

  def repair_transitions
    if data_type == CARD_DATA_TYPE
      used_by_transitions.each do |transition|
        transition.save
      end
    end
  end

  def update_aggregates
    AggregatePropertyDefinition.update_aggregates_using_project_variable(self)

  end

  def card_data_type?
    self.data_type == CARD_DATA_TYPE
  end

end
