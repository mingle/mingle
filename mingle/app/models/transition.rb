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

class Transition < ActiveRecord::Base

  USER_INPUT_REQUIRED = "(user input - required)" unless defined?(USER_INPUT_REQUIRED)
  USER_INPUT_OPTIONAL = "(user input - optional)" unless defined?(USER_INPUT_OPTIONAL)
  USER_INPUT_VALUES = [USER_INPUT_OPTIONAL, USER_INPUT_REQUIRED] unless defined?(USER_INPUT_VALUES)

  belongs_to :project
  belongs_to :card_type

  has_many :actions, :class_name => "::TransitionAction", :dependent => :destroy, :as => :executor
  has_many :prerequisites, :class_name => "TransitionPrerequisite", :include => [:project_variable], :dependent => :destroy

  validates_uniqueness_of :name, :scope => 'project_id', :case_sensitive => false
  validates_presence_of :name
  skip_has_many_association_validations
  strip_on_write
  use_database_limits_for_all_attributes

  named_scope :order_by_name, :order => 'lower(name)'

  def to_xml(options={})
    TransitionSerializer.new(self).to_xml(options)
  end

  def reload_with_clearing_cache(options = {})
    clear_cached_results_for(:prerequisites_collection)
    reload_without_clearing_cache(options)
  end
  alias_method_chain :reload, :clearing_cache unless method_defined?(:reload_without_clearing_cache)

  def property_definition_transition_actions
    self.actions.select { |ta| ta.is_a?(PropertyDefinitionTransitionAction) }
  end

  def optional_input_actions
    self.actions.select { |ta| ta.is_a?(UserInputOptionalTransitionAction) }
  end

  def display_actions
    tree_actions, non_tree_actions = actions.partition { |action| action.property_definition.is_a?(TreeBelongingPropertyDefinition) || action.property_definition.is_a?(TreeRelationshipPropertyDefinition) }
    (non_tree_actions.sort_by { |action| order_by(action.property_definition) }).tap do |result|
      grouped_tree_actions = project.tree_configurations.smart_sort_by(&:name).collect do |tree_configuration|
        tree_actions.select { |action| action.property_definition.tree_configuration_id == tree_configuration.id }
      end

      # Add tree relationship property actions.
      grouped_tree_actions.each do |tree_group|
        tree_group.each do |action|
          result << action unless action.property_definition.is_a?(TreeBelongingPropertyDefinition)
        end
      end

      # Add tree belonging actions.
      grouped_tree_actions.each do |tree_group|
        tree_group.each do |action|
          if (action.property_definition.is_a?(TreeBelongingPropertyDefinition))
            result << action
            action.property_definition.tree_configuration.card_types_before(self.card_type).each do |tree_card_type|
              relationship = action.property_definition.tree_configuration.find_relationship(tree_card_type)
              result << create_set_value_action(relationship, PropertyValue::NOT_SET_VALUE)
            end
          end
        end
      end
    end
  end

  def display_required_properties
    tree_required_properties, non_tree_requried_properties = required_properties.partition do |required_property|
      required_property.property_definition.is_a?(TreeBelongingPropertyDefinition) || required_property.property_definition.is_a?(TreeRelationshipPropertyDefinition)
    end
    non_tree_requried_properties.sort_by { |action| order_by(action.property_definition) } + tree_required_properties.smart_sort_by(&:name)
  end

  def has_tree_belonging_actions?(tree_configuration)
    actions.any? { |action| action.is_a?(RemoveFromTreeTransitionAction) && action.tree_configuration == tree_configuration }
  end

  def prerequisites_collection(skip_user_based_prerequisites=false)
    feed_to_collection = prerequisites_of_type(HasSpecificValue) + prerequisites_of_type(HasSetValue)
    user_based_prerequisites = skip_user_based_prerequisites ? {} : user_prerequisites + group_prerequisites
    feed_to_collection << OrPrerequisitesCollection.new(user_based_prerequisites) if user_based_prerequisites.any?
    AndPrerequisitesCollection.new(feed_to_collection)
  end
  memoize :prerequisites_collection

  # TODO: Make this private if we still keep it.
  def order_by(prop_def)
    if prop_def.is_a?(TreeBelongingPropertyDefinition)
      order_by_tree_belonging_property_definition(prop_def)
    else
      card_type ? card_type.position_of(prop_def) : prop_def.name
    end
  end
  private :order_by

  def available_to?(card, skip_user_based_prerequisites=false)
    if self.card_type.nil? || self.card_type == card.card_type
      prerequisites_collection(skip_user_based_prerequisites).satisfied_by(card)
    end
  end

  def available_to_all_users?
    (user_prerequisites + group_prerequisites).empty?
  end

  def completable_on?(card=nil)
    return !require_comment if card.blank?

    available_to?(card) && require_user_to_enter_property_definitions.all?{|pd| not pd.value(card).blank?} && (require_comment ? (not card.comment.blank?) : true)
  end

  def specified_to_user?(user)
    return false unless user
    user_prerequisites.any?{|prerequisite|prerequisite.user == user }
  end

  def uses_group?(group)
    group_prerequisites.any?{|prerequisite|prerequisite.group == group }
  end

  def remove_specified_to_user(user)
     user_prerequisite = user_prerequisites.detect { |prerequisite| prerequisite.user == user }
     user_prerequisite.destroy if user_prerequisite
  end

  def uses?(property_value)
    (actions + prerequisites).any?{|participant| participant.uses?(property_value) }
  end

  def self.find_any_specifying_user(member, conditions={})
    query = %Q{
      SELECT t.id
      FROM #{TransitionPrerequisite.quoted_table_name} tp
        INNER JOIN #{Transition.quoted_table_name} t ON t.id=tp.transition_id
      WHERE tp.type='IsUser' AND tp.user_id=#{member.id}
    }
    if conditions[:project]
      query << " AND t.project_id=#{conditions[:project].id}"
    end

    ActiveRecord::Base.connection.select_values(query).collect do |transition_id|
      Transition.find_by_id(transition_id)
    end

  end

  def self.find_all_using_member(member, conditions={})
    prerequisite_query = %Q{
      SELECT tp.transition_id
        FROM #{TransitionPrerequisite.quoted_table_name} tp
        INNER JOIN #{PropertyDefinition.quoted_table_name} pd ON pd.id=tp.property_definition_id AND pd.type='UserPropertyDefinition'
      WHERE tp.value='#{member.id}'
    }
    if conditions[:project]
      prerequisite_query << " AND pd.project_id=#{conditions[:project].id}"
    end

    member_used_in_prerequisites = ActiveRecord::Base.connection.select_values(prerequisite_query)

    actions_query = %Q{
      SELECT ta.executor_id AS transition_id FROM #{TransitionAction.quoted_table_name} ta
        INNER JOIN #{PropertyDefinition.quoted_table_name} pd ON pd.id=ta.target_id AND pd.type='UserPropertyDefinition'
      WHERE ta.value='#{member.id}' AND executor_type='Transition'
    }
    if conditions[:project]
      actions_query << " AND pd.project_id=#{conditions[:project].id}"
    end

    member_used_in_actions = ActiveRecord::Base.connection.select_values(actions_query)

    (member_used_in_prerequisites + member_used_in_actions).collect do |transition_id|
      Transition.find_by_id(transition_id)
    end
  end

  def self.used_user_ids
    ThreadLocalCache.get("Transition.used_user_ids") do
      actions_query = %Q{
        SELECT ta.value FROM #{TransitionAction.quoted_table_name} ta
        INNER JOIN #{PropertyDefinition.quoted_table_name} pd
                ON pd.id=ta.target_id
                AND pd.type='UserPropertyDefinition'
        WHERE executor_type='Transition'}
      prerequisite_query = %Q{
        SELECT tp.value
          FROM #{TransitionPrerequisite.quoted_table_name} tp
          INNER JOIN #{PropertyDefinition.quoted_table_name} pd
                ON pd.id=tp.property_definition_id
                AND pd.type='UserPropertyDefinition'}
      specifying_user_query = %Q{
        SELECT tp.user_id
        FROM #{TransitionPrerequisite.quoted_table_name} tp
          INNER JOIN #{Transition.quoted_table_name} t ON t.id=tp.transition_id
        WHERE tp.type='IsUser'}
      [actions_query, prerequisite_query, specifying_user_query].map do |q|
        self.connection.select_values(q).uniq.compact.map(&:to_i)
      end.flatten.uniq
    end
  end

  def uses_property_definition?(definition)
    (required_properties + target_properties).any?{|property| property.property_definition == definition}
  end

  def uses_tree?(tree_configuration)
    actions.any? { |participant| participant.uses_tree?(tree_configuration) }
  end

  def uses_project_variable?(project_variable)
    (actions + prerequisites).any? { |participant| participant.uses_project_variable?(project_variable) }
  end

  def change_project_variable_usage(old_variable, new_variable, new_binding)
    return unless uses_project_variable?(old_variable)
    prerequisites.each { |prerequisite| prerequisite.change_project_variable_usage(old_variable, new_variable) }
    actions.each do |action|
      action.variable_binding = new_binding
      action.save
    end
  end

  def execute(card, user_entered_properties={}, comment = nil)
    if available_to?(card)
      actions.each { |action| action.execute(card, user_entered_properties) }
      card.comment = comment
      if !card.errors.empty? || !card.valid?
        card.errors.each_full {|error_msg| self.errors.add_to_base(error_msg)}
      else
        card.save if card.altered?
      end
    else
      raise TransitionNotAvailableException.new("#{name.bold} is not applicable to Card ##{card.number}.")
    end
  end

  def execute_with_validation(card, user_entered_properties={}, comment = nil)
    if (valid_on_execute?(user_entered_properties, comment))
      begin
        execute(card, user_entered_properties, comment)
      rescue TransitionNotAvailableException => e
        self.errors.add_to_base(e.message)
      end
    end
  end

  def add_set_value_actions(sets_properties)
    if sets_properties
      sets_properties.each do |property_def_name, value|
        add_set_value_action(property_def_name, value)
      end
    end
  end

  def add_set_value_action(property_definition_name, set_value)
    new_action = create_set_value_action(property_definition(property_definition_name), set_value)
    actions << new_action if new_action
  end

  def add_value_prerequisites(requires_properties)
    return unless requires_properties

    requires_properties.each do |property_def_name, value|
      add_value_prerequisite(property_def_name, value)
    end
  end

  def add_value_prerequisite(property_definition_name, required_value)
    property_definition = property_definition(property_definition_name)

    if required_value == PropertyValue::SET_VALUE
      prerequisites << HasSetValue.new(:transition_id => self.id, :property_definition => property_definition)
      return
    end

    if project_variable = property_definition.project_variables.detect { |pv| pv.display_name == required_value }
      prerequisites << HasSpecificValue.new(:transition_id => self.id, :property_definition => property_definition, :project_variable => project_variable)
    else
      required_property = PropertyValue.create_from_db_identifier(property_definition, required_value)
      return if required_property.ignored?
      prerequisites << HasSpecificValue.new(:transition_id => self.id, :required_property => required_property)
    end
  end

  def add_user_prerequisites(user_ids)
    project_user_ids = project.users.all(:select => "#{User.quoted_table_name}.id").collect(&:id)
    (user_ids || []).each do |user_id|
      next unless project_user_ids.include?(user_id.to_i)
      prerequisites << IsUser.new(:transition_id => self.id, :user_id => user_id)
    end
  end

  def add_group_prerequisites(group_ids)
    (group_ids || []).each do |group_id|
      next unless project.group_ids.include?(group_id.to_i)
      prerequisites << InGroup.new(:transition_id => self.id, :group_id => group_id)
    end
  end

  def add_remove_card_from_tree_actions(sets_tree_belongings)
    if sets_tree_belongings
      sets_tree_belongings.each do |tree_id, value|
        tree = self.project.tree_configurations.find(tree_id)
        add_remove_card_from_tree_action(tree, value)
      end
    end
  end

  def add_remove_card_from_tree_action(tree_configuration, value)
    target_property = PropertyValue.create_from_db_identifier(TreeBelongingPropertyDefinition.new(tree_configuration, PropertyType::TreeBelongingType.new), value)
    return if target_property.ignored?
    if value == TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE
      actions << RemoveFromTreeTransitionAction.create_with_children_action(:executor => self, :tree => tree_configuration)
    else
      actions << RemoveFromTreeTransitionAction.create_without_children_action(:executor => self, :tree => tree_configuration)
    end
  end

  def value_required_for(property_definition)
    related_prerequisite = prerequisites.detect { |p| p.property_definition == property_definition }
    return PropertyValue::IGNORED_IDENTIFIER unless related_prerequisite
    return PropertyValue::SET if related_prerequisite.set_value?
    return nil if related_prerequisite.value.blank? && related_prerequisite.project_variable.nil?
    return related_prerequisite.required_property.db_identifier
  end

  def value_set_for(property_definition)
    related_actions = actions.select{|a| a.property_definition == property_definition}
    return PropertyValue::IGNORED_IDENTIFIER if related_actions.empty?
    related_actions.first.target_property.db_identifier
  end

  def validate
    self.errors.add_to_base("Transition must #{'set'.bold} at least one property.") if actions.empty?
    self.errors.add_to_base("Transition cannot set more than one relationship property per tree.") if sets_more_than_one_relationship_per_tree
    self.prerequisites.each {|pr| pr.validate; pr.errors.full_messages.uniq.each {|e|self.errors.add_to_base(e)}}
    self.actions.reject(&:require_user_to_enter).each {|a| a.validate; a.errors.full_messages.uniq.each {|e| self.errors.add_to_base(e)}}
    self.errors.add_to_base("Transition can't have both is user and in group prerequisites") if has_user_prerequisites? && has_group_prerequisites?
  end

  def valid_on_execute?(user_entered_properties, comment)
    user_entered_properties ||= {}
    require_user_to_enter_property_definitions.collect(&:name).each do |property_name|
      user_entered_property_name = user_entered_properties.keys.detect do |user_entered_property_name|
        user_entered_property_name.to_s.ignore_case_equal?(property_name)
      end
      if user_entered_property_name.blank? || user_entered_properties[user_entered_property_name].blank?
        self.errors.add_to_base("Value of #{property_name} property for this transition must not be empty.")
      end
    end

    if require_comment && comment.blank?
      self.errors.add_to_base("Transition #{name.bold} requires a comment.")
    end

    self.errors.empty?
  end

  def user_prerequisites
    prerequisites_of_type(IsUser)
  end

  def has_user_prerequisites?
    !user_prerequisites.empty?
  end

  def group_prerequisites
    prerequisites_of_type(InGroup)
  end

  def has_group_prerequisites?
    !group_prerequisites.empty?
  end

  def clean_actions_and_prerequisites!
    self.prerequisites.destroy_all
    self.actions.destroy_all
  end

  def clean_card_property_definitions!
    prerequisites.each do |prerequisite|
      next unless prerequisite.property_definition
      if (PropertyType::CardType === prerequisite.property_definition.property_type && prerequisite.project_variable.nil?)
        prerequisite.destroy
      end
    end
    actions.each do |action|
      if action.uses_any_card?
        action.value = PropertyValue::NOT_SET_VALUE_PAIR.last
        action.save!
      end
    end
  end

  def describe_usability
    group_prerequisites = self.group_prerequisites.map { |prereq| prereq.group.name.bold }
    user_prerequisites = self.user_prerequisites.map { |prereq| prereq.user.name.bold }
    if group_prerequisites.any?
      "This transition can be used by members of the following user #{'group'.plural(group_prerequisites.size)}: #{group_prerequisites.smart_sort.to_sentence}"
    elsif user_prerequisites.any?
      "This transition can be used by the following #{'user'.plural(user_prerequisites.size)}: #{user_prerequisites.smart_sort.to_sentence}"
    else
      "This transition can be used by all team members"
    end
  end

  def required_properties
    prerequisites.collect(&:required_property).compact
  end
  memoize :required_properties

  def target_properties
    actions.collect(&:target_property).compact
  end
  memoize :target_properties

  def display_target_properties
    display_actions.collect(&:target_property).compact
  end

  def used_by_user
    user_prerequisites.collect(&:user)
  end

  def used_by_group
    group_prerequisites.collect(&:group)
  end

  def require_user_to_enter?
    actions.any?{|action| action.require_user_to_enter}
  end

  def has_optional_input?
    !optional_input_actions.empty?
  end

  def accepts_user_input?
    self.require_comment || actions.any? { |action| action.accepts_user_input? }
  end

  def require_user_to_enter_property_definitions
    actions.select{|action| action.require_user_to_enter}.collect(&:property_definition)
  end

  def require_user_to_enter_property_definitions_in_smart_order
    require_user_to_enter_property_definitions.smart_sort_by { |property_definition| order_by(property_definition) }
  end

  def accepts_user_input_property_definitions
    actions.select { |action| action.accepts_user_input? }.collect(&:property_definition)
  end

  def accepts_user_input_property_definitions_in_smart_order
    accepts_user_input_property_definitions.smart_sort_by { |property_definition| order_by(property_definition) }
  end

  def to_s
    "".tap do |result|
      result << name << "\n"
      prerequisites.each { |p| result << "requires #{p.property_definition.name} => #{p.value}\n" }
      result << "and\n"
      actions.each { |a| result << "#{a.to_s}\n" }
    end
  end

  def card_type_name
    card_type && card_type.name
  end

  # optimization
  def project
    Project.current
  end

  def self.map_from_transition_id_to_card_type_and_property_definitions(transitions)
    transitions.map(&:property_mappings_detail)
  end

  def property_mappings_detail
    result = []
    (display_target_properties.collect(&:property_definition) + display_required_properties.collect(&:property_definition)).uniq.each do |prop_def|
      next if prop_def.kind_of?(TreeBelongingPropertyDefinition)  # This type does not have id
      from_value = required_properties.find { |prop_value| prop_value.property_definition == prop_def }.try(:sort_value)
      to_value   = target_properties.find { |prop_value| prop_value.property_definition == prop_def }.try(:sort_value)

      transition_property_def_relation = { :id => prop_def.id, :name => prop_def.name }
      transition_property_def_relation.merge!(:from => from_value) if from_value
      transition_property_def_relation.merge!(:to => to_value) if to_value

      result.push(transition_property_def_relation)
    end

    {
      :transition_id        => id,
      :card_type            => card_type_name,
      :card_type_id         => card_type_id,
      :property_definitions => result,
      :transition_name      => name
    }
  end

  private

  def order_by_tree_belonging_property_definition(prop_def)
    first_prop_def = prop_def.tree_configuration.relationships.first
    transition_card_type_is_first_card_type_in_tree = first_prop_def.valid_card_type == self.card_type

    if transition_card_type_is_first_card_type_in_tree
      prop_def.name
    else
      # put tree belonging just before first property definition in tree
      card_type.position_of(first_prop_def) - 0.5
    end
  end

  def create_set_value_action(property_definition, set_value)
    project_variable = property_definition.project_variables.detect { |pv| pv.display_name == set_value }
    target_property = PropertyValue.create_from_db_identifier(property_definition, set_value)
    return if target_property.ignored?
    TransitionAction.new_property_definition_transition_action(:executor_id => self.id,
                                                               :executor_type => self.class,
                                                               :target_property => target_property,
                                                               :require_user_to_enter => target_property.db_identifier == USER_INPUT_REQUIRED,
                                                               :user_input_optional => target_property.db_identifier == USER_INPUT_OPTIONAL)
  end

  def build_remove_for_users(prerequisites_or_actions, user)
    prerequisites_or_actions.inject({}) do |aggregate, prerequisite_or_action|
      if prerequisite_or_action.includes_user?(user)
        property_name = prerequisite_or_action.property_definition.name
        aggregate[user.name] = aggregate[user.name].nil? ? [property_name] : (aggregate[user.name] << property_name)
      end
      aggregate
    end
  end

  def prerequisites_of_type(type)
    prerequisites.select {|prerequisite| prerequisite.class == type}
  end

  def property_definition(property_definition_name)
    project.find_property_definition(property_definition_name, :with_hidden => true)
  end

  def property_definition_id(property_def_name)
    project.find_property_definition(property_def_name).id
  end

  def sets_more_than_one_relationship_per_tree
    relationship_actions = actions.select { |action| action.property_definition.is_a?(TreeRelationshipPropertyDefinition) }
    tree_ids = relationship_actions.collect do |action|
      action.property_definition.tree_configuration.id
    end.uniq
    tree_ids.size < relationship_actions.size
  end
end

class TransitionNotAvailableException < StandardError

  def initialize(message)
    super(message)
  end
end

class TransitionPrerequisite < ActiveRecord::Base
  belongs_to :transition
  belongs_to :property_definition
  belongs_to :project_variable

  def project
    ThreadLocalCache.get_assn(self, :transition, :project)
  end

  def satisfied_by(card)
    raise "implement me!"
  end

  def includes_user?(user)
    property_definition.is_a?(UserPropertyDefinition) && value.to_i == user.id
  end

  def uses_project_variable?(project_variable)
    self.project_variable == project_variable
  end

  def change_project_variable_usage(old_variable, new_variable)
    update_attributes(:project_variable => new_variable) if uses_project_variable?(old_variable)
  end

  def validate
    validate_attempt_to_create_plv
  end

  def validate_attempt_to_create_plv
    errors.add_to_base(property_definition.attemped_to_create_plv_from_transition(value)) if ProjectVariable.is_a_plv_name?(value)
  end

  def set_value?
    false
  end
end

class OrPrerequisitesCollection
  attr_accessor :prerequisites
  def initialize(prerequisites)
    self.prerequisites = prerequisites
  end

  def satisfied_by(card)
    prerequisites.any?{|prerequisite| prerequisite.satisfied_by(card)}
  end
end

class AndPrerequisitesCollection
  attr_accessor :prerequisites

  def initialize(prerequisites)
    self.prerequisites = prerequisites
  end

  def satisfied_by(card)
    prerequisites.all?{|prerequisite|prerequisite.satisfied_by(card)}
  end
end

class HasSpecificValue < TransitionPrerequisite
  def satisfied_by(card)
    if project_variable
      card.property_value(property_definition) == PropertyValue.create_from_db_identifier(property_definition, project_variable.value)
    else
      card.property_value(property_definition) == required_property
    end
  end

  def uses?(property_value)
    required_property == property_value
  end

  def uses_member?(property_value)
    return false if required_property.has_current_user_special_value?
    uses?(property_value)
  end

  def required_property
    if project_variable
      VariableBinding.find_by_property_definition_id_and_project_variable_id(property_definition.id, project_variable.id)
    else
      PropertyValue.create_from_db_identifier(property_definition, value)
    end
  end

  def value
    if project_variable
      project_variable.value
    else
      super
    end
  end

  def required_property=(property_value)
    self.property_definition = property_value.property_definition
    self.value = property_value.db_identifier
  end

  def validate
    property_definition.validate_transition_prerequisite(self)
    super
  end

  def to_s
    "Has value of #{required_property.display_value.bold} for #{property_definition.name.bold}"
  end
end

class HasSetValue < TransitionPrerequisite
  def satisfied_by(card)
    card.property_value(property_definition).set?
  end

  def required_property
    PropertyValueSet.new(property_definition)
  end

  def value
    PropertyValue::SET
  end

  def validate
    true
  end

  def set_value?
    true
  end

  def uses_member?(property_value)
    false
  end

  def uses?(property_value)
    false
  end

  def to_s
    "Has value set for #{property_definition.name.bold}"
  end
end

class CardIndependentTransitionPrerequisite < TransitionPrerequisite
  def required_property
    nil
  end

  def uses?(property_value)
    false
  end

  def validate
    true
  end
end

class IsUser < CardIndependentTransitionPrerequisite
  belongs_to :user

  def satisfied_by(card)
    user_id == User.current.id
  end

  def uses_member?(property_value)
    uses?(property_value)
  end

  def to_s
    "User is #{user.name}"
  end
end

class InGroup < CardIndependentTransitionPrerequisite

  belongs_to :group

  def satisfied_by(card)
    group.member?(User.current)
  end
end
