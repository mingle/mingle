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

class TreeConfiguration < ActiveRecord::Base

  class InvalidChildException < StandardError
    def initialize()
       @errors = []
    end

    def add_error(error)
      @errors << error
    end

    def errors
      errors = @errors.uniq
      if errors.size > 1
        errors = errors.inject([]) { |errors, error| errors << error.slice(0, error.index('.') + 1) }
        errors << 'No cards have been added to the tree.'
      end
      errors
    end
  end

  include SqlHelper
  VALID_NAME_PATTERN = /^([^\[\]&=#]+)$/

  has_many :relationships, :class_name => "TreeRelationshipPropertyDefinition", :foreign_key => "tree_configuration_id", :order => :position, :dependent => :destroy
  belongs_to :project
  has_many :tree_belongings, :include => :card
  has_many :aggregate_property_definitions, :class_name => "AggregatePropertyDefinition", :foreign_key => "tree_configuration_id", :dependent => :destroy

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id, :case_sensitive => false
  validates_format_of :name, :with => VALID_NAME_PATTERN, :message => "should not contain '&', '=', '#', '[' and ']' characters", :if => Proc.new{|record| !record.name.blank?}

  acts_as_attribute_changing_observable
  strip_on_write
  use_database_limits_for_all_attributes

  def project
    Project.current
  end

  def before_destroy
    TreeBelonging.delete_all(['tree_configuration_id = ?', self.id])
    transitions_to_destroy = project.transitions.select do |transition|
      transition.actions.any? { |action| action.is_a?(RemoveFromTreeTransitionAction) && action.tree_configuration.id == self.id }
    end
    transitions_to_destroy.each(&:destroy)
    project.card_list_views.select{ |view| view.tree_name.ignore_case_equal?(self.name)}.each(&:destroy)
    project.card_list_views.select{ |view| view.uses_from_tree_as_condition?(self.name)}.each(&:destroy)
  end

  def name=(new_name)
    # important to do renaming of associated objects before
    # changing my own name in order that they be valid when loaded.
    if name && name != new_name && record_exists?
      update_card_views_on_name_change(new_name)
    end
    write_attribute(:name, new_name)
  end

  def relationships
    ret = project.property_definitions_with_hidden.select{ |pd| pd.class == TreeRelationshipPropertyDefinition && pd.tree_configuration_id == id }
    ret.sort_by(&:position)
  end

  def tree_property_definitions
    [tree_belong_property_definition] + relationships
  end

  def tree_belong_property_definition
     TreeBelongingPropertyDefinition.new(self)
  end

  def relationship_map
    RelationshipsMap.new(relationships)
  end
  memoize :relationship_map

  def related_transitions
    project.transitions.select do |transition|
      transition.uses_tree?(self) || (relationships + aggregate_property_definitions).any?{ |pd| transition.uses_property_definition?(pd) }
    end.collect(&:name)
  end

  def expanded_card_names(condition = nil)
    CardQuery.new(:columns => relationship_map.mql_columns, :conditions => condition).values_as_expanded_card_names
  end

  def abbreviated_card_names(condition = nil)
    CardQuery.new(:columns => relationship_map.mql_columns, :conditions => condition).values_as_abbreviated_card_names
  end

  def validate
    errors.add :name, "has already been taken by a property." if project.property_definitions_with_hidden.collect(&:name).any?{|prop_name| prop_name.ignore_case_equal?(self.name)}
    errors.add :name, "cannot be #{name.bold}" if (name =~ /\A\s*none\s*\Z/i)
  end

  def validate_card(card, original_values_of_changed_properties)
    return unless invalid_card_type?(card)

    my_changed_property_values = original_values_of_changed_properties.collect{|value| value.property_definition.property_value_on(card)}.sort_by {|value| value.property_definition.position }
    parent_card = nil
    invalid = false
    my_changed_property_values.each do |value|
      if parent_card.nil?
        parent_card = if value.db_identifier.nil?
          relationship_to_parent_card_type = relationship_map.relationship_to_parent_card_type(value.property_definition.valid_card_type)
          if relationship_to_parent_card_type
            property_value = relationship_to_parent_card_type.property_value_on(card)

            project.cards.find_by_id(property_value.db_identifier)
          end
        else
          project.cards.find(value.db_identifier)
        end
        next
      end

      next if value.db_identifier.nil?

      child_card = project.cards.find(value.db_identifier)

      unless contains?(parent_card, child_card)
        invalid = true
        break
      end
      parent_card = child_card
    end

    if parent_card && !type_contains?(parent_card.card_type, card.card_type)
      card.errors.add_to_base("Since type #{parent_card.card_type.name.bold} cannot contain type #{card.card_type.name.bold}, cannot set #{tree_relationship_name(parent_card.card_type).bold} as #{parent_card.name.bold}")
    end

    if invalid
      card.errors.add_to_base("Suggested location on tree #{name.bold} is invalid.")
      error_property_values = my_changed_property_values.collect{|value| "#{value.name.bold} as #{value.display_value.bold}" }
      card.errors.add_to_base("Cannot have #{error_property_values.to_sentence} at the same time.")
    end
  end

  def validate_card_fully(card)
    parent_card = nil
    relationships.reverse.each do |relationship|
      unless relationship.db_identifier(card).blank?
        parent_card = project.cards.find(relationship.db_identifier(card))
        break
      end
    end

    if parent_card && !include_card?(parent_card)
      card.errors.add_to_base("Suggested parent card isn't on tree #{name.bold}")
    elsif parent_card
      relationship_map.each_before(parent_card.card_type) do |relationship|
        card_id = relationship.db_identifier(card)
        parent_card_id = relationship.db_identifier(parent_card)
        if relationship.db_identifier(card) != relationship.db_identifier(parent_card)
          card.errors.add_to_base("Suggested location on tree #{name.bold} is invalid.")
        end
      end
    end
  end

  def invalid_card_type?(card)
    unless type_contains?(:tree, card.card_type)
      card.errors.add_to_base("Card tree #{name.bold} cannot contain #{card.card_type.name} cards.")
      return false
    else
      return true
    end
  end

  def include_card_type?(card_type)
    all_card_types.include?(card_type)
  end

  def revise_tree_structure(card, original_values_of_changed_properties)
    relationship = original_values_of_changed_properties.sort_by {|value| value.property_definition.position }.last.property_definition
    relationship_map.each_after(relationship.valid_card_type) { |r| r.remove_value(card) }

    parent_ids = relationship_map.parent_card_ids(card)
    parent_card = parent_ids.empty? ? :root : project.cards.find(parent_ids.last)

    if parent_card == :root
      relationship_map.each { |r| r.remove_value(card) }
    else
      relationship_map.each_before(parent_card.card_type){ |r| r.clone_value(parent_card, card) }
      relationship_map.each_after(parent_card.card_type) { |r| r.remove_value(card) }
    end

    if include_card?(card) && !card.new_record?
      children_cards = sub_tree_card_query(card, :include_root => false).find_base_info_cards
      move_cards(card, children_cards, :to => parent_card) unless children_cards.blank?
    end
  end

  def update_warnings(card_types={})
    deleted_card_types = all_card_types - card_types.keys

    unless deleted_card_types.blank?
      deleted_relationships = relationship_map.sub(generate_relationships(card_types))
      {
        :card_type => deleted_card_types.collect(&:name),
        :property => deleted_relationships.collect(&:name),
        :transition => transitions_to_delete(deleted_card_types, deleted_relationships).collect(&:name),
        :card_defaults => card_defaults_to_delete_relationships(deleted_card_types, deleted_relationships).collect(&:card_type_name),
        :aggregate => aggregates_to_delete(deleted_card_types).collect(&:name),
        :plv => project.project_variables.select { |plv| deleted_relationships.any?{ |rel| plv.property_definitions.include?(rel) } }.collect(&:name),
        :card_list_views => expand_view_to_delete(deleted_card_types, project.card_list_views.select(&:team?)).collect(&:name) + deleted_property_related_team_views(deleted_relationships).collect(&:name)
      }
    end
  end

  def update_card_types(card_type_details={})
    old_types = all_card_types
    card_types = card_types_from_details(card_type_details)
    deleted_card_types = old_types - card_types
    relationship_names = card_type_details.inject([]) do |result, card_type_detail|
      result[card_type_detail.last[:position].to_i] = card_type_detail.last[:relationship_name]
      result
    end.compact
    return true if !card_types.empty? && card_types == all_card_types && relationship_map.collect(&:name).sort == relationship_names.sort
    return unless validate_card_types(card_types)

    aggregates_to_delete = aggregates_to_delete(deleted_card_types)

    return false if deletion_of_aggregates_invalid?(aggregates_to_delete)

    all_card_types.each { |t| remove_cards_of_type(t) unless card_types.include?(t) }
    relationships_to_destroy = relationship_map.select { |r| !card_types[0..-2].include?(r.valid_card_type) }
    transitions_to_delete(deleted_card_types, relationships_to_destroy).each(&:destroy)
    update_remove_from_tree_values(deleted_card_types)

    expand_view_to_delete(deleted_card_types).each(&:destroy)
    update_card_default_relationships(deleted_card_types, relationships_to_destroy)
    aggregates_to_delete.each(&:destroy)

    relationships_to_destroy.each(&:destroy)
    # clear_cached_results_for :relationship_map

    new_relationships = create_new_relationships(card_type_details)
    clear_cached_results_for :relationship_map

    return false if self.errors.any?
    new_relationships.each(&:save)
    project.property_definitions_with_hidden.reload
    refresh_property_types_mapping(card_types)
    clear_cached_results_for :relationship_map
    # recompute aggregates, starting from the lowest type involved in the config change
    new_types = card_types
    if old_types != new_types
      [old_types, new_types].each(&:pop) while (new_types.last == old_types.last)
      new_types.reverse.each do |type|
        type.reload.aggregate_property_definitions.select { |aggregate| aggregate.tree_configuration_id == self.id }.each(&:update_cards)
      end
    end

    project.reload.update_card_schema if save
    save
  end

  def create_tree(tree_query_options={})
    CardTree.new(self, tree_query_options)
  end

  def create_expanded_tree(expanded_node_numbers, tree_query_options={})
    CardTree.new(self, tree_query_options.merge(:expanded => expanded_node_numbers, :visible_only => true))
  end

  def cards_count
    tree_belongings.count
  end

  def configured?
    !relationship_map.empty?
  end

  def all_card_types
    relationship_map.card_types
  end

  def contains?(left_card, right_card)
    return false if left_card.card_type_name == right_card.card_type_name

    if prop_def = relationship_map.relationship_for_card_type(left_card.card_type)
      left_card.id == right_card.send(prop_def.column_name)
    end
  end

  def type_contains?(left_type, right_type)
    return true if left_type == :tree && all_card_types.include?(right_type)
    return unless all_card_types.include?(right_type) && all_card_types.include?(left_type)
    all_card_types.index(left_type) < all_card_types.index(right_type)
  end

  def card_type_index(card_type)
    relationship_map.card_type_index(card_type)
  end

  def find_all_ancestor_cards(card)
    raise "#{card.number_and_name} is not in the tree #{name}" unless include_card?(card)
    find_all_ancestor_cards_without_validation(card)
  end

  def find_all_ancestor_cards_without_validation(card)
    ids = parent_card_ids(card)
    return [] if ids.blank?
    cards = Card.find_all_by_id(ids)
    ids.map { |id| cards.detect { |card| card.id == id } }
  end

  class LightweightCard < Struct.new(:id, :card_type_name); end

  def unique_ancestors_of_cards(card_id_criteria)
    column_names = relationships.collect(&:column_name)
    sql = "SELECT id, card_type_name, #{column_names.join(', ')} FROM #{Card.quoted_table_name} WHERE id #{card_id_criteria.to_sql}"
    deleted_cards = Card.connection.select_all(sql)
    ancestors = deleted_cards.collect {|card| relationships.collect {|prop| LightweightCard.new(card[prop.column_name], prop.valid_card_type.name)}.reject {|card| card.id.nil?}}.flatten.uniq
    deleted_card_ids = deleted_cards.collect{|card| card['id']}
    ancestors.reject! {|ancestor| deleted_card_ids.include?(ancestor.id)}
    ancestors
  end

  def compute_aggregates_for_unique_ancestors(card_id_criteria)
    ancestors = unique_ancestors_of_cards(card_id_criteria)
    ancestors.group_by(&:card_type_name).each do |card_type_name, ancestors|
      aggregate_property_definitions.select {|prop_def| prop_def.has_card_type?(card_type_name)}.each do |prop|
        if block_given?
          yield(prop, ancestors)
        else
          prop.compute_aggregates(ancestors)
        end
      end
    end
  end

  def find_parent_card_of(card)
    find_all_ancestor_cards(card).last
  end

  def next_card_type(card_type)
    index = card_type_index(card_type)
    all_card_types[index+1]
  end

  def previous_card_type(card_type)
    index = card_type_index(card_type)
    all_card_types[index-1]
  end

  def card_types_before(card_type)
    index = card_type_index(card_type)
    return [] if index == 0
    all_card_types[0..index-1]
  end

  def card_types_after(card_type)
    index = card_type_index(card_type)
    all_card_types[index+1..-1]
  end

  def find_relationship(card_type)
    relationship_map.relationship_for_card_type(card_type)
  end

  def can_contain_children?(card_type)
    bottom_card_type != card_type
  end

  def tree_relationship_name(card_type)
    return nil unless card_type
    if relationship = relationship_map.relationship_for_card_type(card_type)
      relationship.name
    end
  end

  def containings_count_of(card)
    containings_count_map[card.id] || 0
  end

  def level_in_complete_tree(card)
    return 0 if card == :root
    parent_card_ids(card).size + 1
  end

  def validate_including_card(card)
    raise "Target #{card} does not belong to me(#{name})!" unless include_card?(card)
  end

  def add_card(card)
    unless include_card?(card)
      tree_belongings.create(:card => card)
    end
  end

  def add_child(card, options={:to => :root})
    raise "Tree needs to be configured before adding any nodes" unless configured?
    #todo: the following validations are duplicated with card#validation, should we remove it?
    #      it maybe depend on the implementation of add cards into tree.
    unless type_contains?(:tree, card.card_type)
      raise PropertyDefinition::InvalidValueException.new("Card tree #{name.bold} cannot contain #{card.card_type.name.bold} cards.")
    end

    validate_including_card(options[:to])
    if options[:to] == :root
      relationships.each { |relationship| relationship.update_card(card, nil) }
    else
      validate_type_contains(options[:to].card_type, card.card_type)

      relationship_properties_to_nil_out = {}
      relationship_map.each_after(options[:to].card_type) do |relationship|
        relationship_properties_to_nil_out[relationship] = nil
      end
      relationship_property_to_set = {find_relationship(options[:to].card_type) => options[:to].id}

      card.update_properties(relationship_property_to_set.merge(relationship_properties_to_nil_out))
    end
    card.save

    #add card after card.save, because card#repair_trees can't do anything when adding card to root
    #and for new card, you always need card save before creating tree_belonging otherwise it will create new version for card
    add_card(card)
    card
  end

  def add_children_to(children, parent_card=:root)
    [].tap do |result|
      exception = InvalidChildException.new
      children.each do |card|
        begin
          result << add_child(card, :to => parent_card)
        rescue PropertyDefinition::InvalidValueException => e
          exception.add_error(e.message)
        end
      end
      raise exception if exception.errors.any?
    end
  end

  def remove_card(card, card_type=nil, options = {})
    return [] unless include_card?(card)
    remove_cards_from_tree([card], parent_card_ids(card), options) do
      roll_up_containings(card, card_type)
    end
  end

  def remove_card_and_its_children(card, options={})
    return [] unless include_card?(card)
    if options[:do_not_persist_parent]
      base_info_cards = sub_tree_card_query(card).find_base_info_cards
      base_info_cards_without_parent = base_info_cards.reject {|base_card_info| base_card_info.id == card.id}
      remove_cards_from_tree(base_info_cards_without_parent, [card.id])
      remove_cards_from_tree([card], parent_card_ids(card), :do_not_persist => true)
    else
      remove_cards_from_tree(sub_tree_card_query(card).find_base_info_cards, parent_card_ids(card), options)
    end
  end

  def parent_card_ids(card)
    relationship_map.parent_card_ids(card)
  end

  def is_ancestor?(ancestor_card, card)
    parent_card_ids(card).include?(ancestor_card.id)
  end

  def include_card?(card_or_card_version)
    card = card_or_card_version.respond_to?(:card) ? card_or_card_version.card : card_or_card_version
    return if card.blank?
    return true if card == :root
    tree_belongings.find_by_card_id(card.id)
  end

  def in_tree_condition
    CardQuery::InTree.new(self)
  end

  def sub_tree_condition(card, options={:include_root => false})
    return if !card || card == :root

    if relationship = relationship_map.relationship_for_card_type(card.card_type)
      sql = %{(#{Card.quoted_table_name}.#{relationship.quoted_column_name} = #{card.id})}
      sql += %{ OR (#{Card.quoted_table_name}.id = #{card.id})} if options[:include_root]
    else
      sql = "#{Card.quoted_table_name}.id = #{options[:include_root] ? card.id : -1}"
    end
    CardQuery::SqlCondition.new(sql)
  end

  def sub_tree_card_query(card, options={:include_root => true})
    conditions = CardQuery::And.new(in_tree_condition, sub_tree_condition(card, options))
    CardQuery.new(:conditions => conditions)
  end

  def relationships_available_to(holder)
    available_property_definitions = holder.property_definitions
    relationships.select{|relationship| available_property_definitions.include? relationship}
  end

  def aggregate_property_definitions_available_to(holder)
    available_property_definitions = holder.property_definitions
    aggregate_property_definitions.select{|aggregate| available_property_definitions.include? aggregate}.smart_sort_by(&:name)
  end

  def handle_card_type_change(card, old_card_type)
    if include_card_type?(card.card_type)
      roll_up_containings(card, old_card_type)
    else
      remove_card(card, old_card_type)
    end
  end

  def find_cards_by_numbers(numbers)
    return [] if numbers.blank?
    belongs = self.tree_belongings.find(:all, :conditions => ["#{Card.quoted_table_name}.#{ActiveRecord::Base.connection.quote_column_name('number')} in (?)", numbers])
    belongs.collect(&:card)
  end

  def find_card_by_number(number)
    return nil unless number
    belong = self.tree_belongings.find(:first, :conditions => ["#{Card.quoted_table_name}.#{ActiveRecord::Base.connection.quote_column_name('number')} = ?", number])
    belong.try(:card)
  end

  def find_card_by_parent_node_and_name(parent_card, name)
    return nil unless name
    # todo: when we add index to cards.name, consider to change lower(cards.name) to be the right index format
    name_cond = "LOWER(#{Card.quoted_table_name}.#{ActiveRecord::Base.connection.quote_column_name('name')}) = LOWER(?)"
    conds = if parent_card.nil?
      ["#{name_cond} AND #{relationship_map.first.column_name} IS NULL", name]
    else
      prop = relationship_map.relationship_for_card_type(parent_card.card_type)
      ["#{name_cond} AND #{prop.column_name} = ?", name, parent_card.id]
    end
    if belong = self.tree_belongings.find(:first, :conditions => conds)
      belong.card
    end
  end

  def deletion
    Deletion.new(self, aggregates_to_delete(deleted_card_types({})))
  end

  def deletion_for_update(card_type_details = {})
    Deletion.new(self, aggregates_to_delete(deleted_card_types(card_type_details)))
  end

  def deletion_blockings
    deletion.blockings
  end

  private

  def deleted_card_types(card_type_details)
    all_card_types - card_types_from_details(card_type_details)
  end

  def update_card_views_on_name_change(new_name)
    project.card_list_views.each do |view|
      view.rename_tree(name, new_name)
      view.save!
    end
  end

  def move_cards(card, cards, options)
    parent_relationships_and_values = {}
    relationship_map.each_before(card.card_type) do |r|
      parent_relationships_and_values[r.name] = nil
    end
    unless options[:to] == :root
      validate_type_contains(options[:to].card_type, card.card_type)

      relationship_map.each_before(options[:to].card_type) do |r|
        value_obj = r.value(options[:to])

        parent_relationships_and_values[r.name] = value_obj.nil? ? nil : value_obj.id
      end
      relationship = relationship_map.relationship_for_card_type(options[:to].card_type)
      parent_relationships_and_values[relationship.name] = options[:to].id
    end

    card_selection = CardSelection.new(project, cards)
    card_selection.update_properties(parent_relationships_and_values, {:bypass_versioning => false, :bypass_update_properties_validation => true})
    if card_selection.errors.any?
      card_selection.errors.each {|error| card.errors.add_to_base error}
    end
  end

  def remove_cards_from_tree(removed_cards, need_update_aggregates_card_ids, options = {:change_version => nil})
    set_properties_to_nil(removed_cards, relationship_map, {:bypass_update_aggregates => true, :change_version => options[:change_version], :do_not_persist => options[:do_not_persist]})
    set_properties_to_nil(removed_cards, aggregate_property_definitions, {:bypass_update_aggregates => true, :bypass_versioning => true})
    remove_tree_belonging(removed_cards)

    yield if block_given?

    # I noticed that the following is putting in some nonsense requests -- ones for cards of types that don't even have the aggregate property.
    # This isn't really hurting anything but maybe can be changed later if it can be done without hurting performance.
    need_update_aggregates_card_ids.each do |card_id|
      aggregate_property_definitions.each do |prop_def|
        prop_def.compute_aggregate(card_id)
      end
    end

    removed_cards
  end

  def deleted_property_related_team_views(relationships)
    project.card_list_views.select(&:team?).select do |view|
      relationships.any? { |relationship| view.uses?(relationship) }
    end
  end

  def set_properties_to_nil(removed_cards, prop_defs, options)
    return if prop_defs.empty?
    if options[:do_not_persist]
      removed_cards.each do |removed_card|
        prop_defs.each { |prop_def| prop_def.update_card(removed_card, nil) }
      end
    else
      property_names_and_values = prop_defs.inject({}) do |map, pd|
        map[pd.name] = nil
        map
      end
      CardSelection.new(project, removed_cards).update_properties(property_names_and_values, options.merge(:bypass_update_properties_validation => true))
    end
  end

  def remove_tree_belonging(removed_cards)
    tree_belongings.find_all_by_card_id(removed_cards.collect(&:id)).each(&:destroy)
  end

  def validate_type_contains(parent_card_type, child_card_type)
    unless type_contains?(parent_card_type, child_card_type)
      raise PropertyDefinition::InvalidValueException.new("Type #{parent_card_type.name.bold} cannot contain type #{child_card_type.name.bold}. No cards have been added to the tree.")
    end
    true
  end

  def containings_count_map
    count_sqls = relationship_map.inject([]) do |ret, pd|
      ret << %{
        SELECT #{pd.column_name} AS value_id, COUNT(id) AS count
        FROM #{Card.quoted_table_name}
        WHERE #{pd.column_name} IS NOT NULL
        GROUP BY #{pd.column_name}
      }
    end
    sql = count_sqls.join(' UNION ')
    result_set = select_all_rows(sql)
    result_set.inject({}) do |ret, row|
      ret[row['value_id'].to_i] = row['count'].to_i
      ret
    end
  end
  memoize :containings_count_map

  def create_new_relationships(card_type_details)
    card_types = card_types_from_details(card_type_details)
    new_relationships = generate_relationships(card_type_details)
    detect_non_unique_relationship_names_in(new_relationships)
    detect_blank_relationship_names_in(new_relationships)
    return new_relationships if errors.any?
    new_relationships.each do |r|
      r.position = card_types.index(r.valid_card_type) + 1
      self.errors.add_to_base("Relationship #{r.name.truncate_with_ellipses(25).bold} has errors:#{MingleFormatting::MINGLE_LINE_BREAK_MARKER}#{r.errors.full_messages.collect(&:as_li).join.as_ul}") unless r.valid?
    end
    new_relationships
  end

  def detect_non_unique_relationship_names_in(new_relationships)
    new_relationship_names = new_relationships.sort_by(&:position).collect(&:name)
    duplicates = new_relationship_names.collect(&:downcase).duplicates
    if duplicates.any?
      dups = duplicates.collect { |duplicate_name| new_relationship_names.detect { |n| n.downcase == duplicate_name } }
      self.errors.add_to_base("Relationship #{'name'.plural(dups.size)} #{dups.bold.to_sentence} #{'is'.plural(dups.size)} not unique")
    end
  end

  def detect_blank_relationship_names_in(new_relationships)
    self.errors.add_to_base("Relationship names cannot be blank") if new_relationships.collect(&:name).any?(&:blank?)
  end

  def generate_relationships(card_type_details)
    card_types = card_types_from_details(card_type_details)
    ret = card_type_details.collect do |card_type, details|
      next if card_types.last == card_type
      TreeRelationshipPropertyDefinition.new(:tree_configuration => self, :project => project, :name => details[:relationship_name], :valid_card_type => card_type, :position => (details[:position].to_i + 1))
    end.compact
    ret.collect do |r|
      if existing = relationship_map.relationship_for_card_type(r.valid_card_type)
        if existing.name != r.name
          # do not use update_attribute or name= to avoid updating
          # related models (see PropertyDefinition#name=), as loading these
          # models may trigger tree configuration validations
          previous = existing.name
          existing.write_attribute(:name, r.name)
          existing.save && existing.update_changes_table_on_name_change(previous, r.name)
        end
        existing
      else
        r
      end
    end
  end

  def card_types_from_details(card_type_details)
    card_type_details.inject([]) do |result, card_type_detail|
      result[card_type_detail.last[:position].to_i] = card_type_detail.first
      result
    end.compact
  end

  def refresh_property_types_mapping(card_types)
    PropertyTypeMapping.delete_all(['property_definition_id in (?)', relationship_map.collect(&:id)])
    relationship_map.each_with_index do |r, index|
      card_types[(index + 1)..-1].each{ |t| t.add_property_definition(r) }
    end
  end

  def has_reverse_types?(card_types)
    card_types[0..-2].any? do |container_type|
      next unless all_card_types.include?(container_type)
      index = card_types.index(container_type)
      card_types[(index + 1)..-1].any? do  |containing_type|
        next unless all_card_types.include?(containing_type)
        card_type_index(container_type) > card_type_index(containing_type)
      end
    end
  end

  def deletion_of_aggregates_invalid?(aggregates_to_delete)
    aggregate_errors = []
    aggregates_to_delete.each do |a|
      a.deletion.blockings.each do |blocking|
        aggregate_errors << blocking
        errors.add_to_base("#{a.name.bold} is #{blocking.description}")
      end
    end
    aggregate_errors.any?
  end

  def validate_card_types(card_types)
    if card_types.size < 2
      errors.add_to_base("You must specify at least 2 valid card types to save this tree.")
      return false
    end

    if has_reverse_types?(card_types)
      errors.add_to_base("To reorganize the type relationships of an existing tree, you must first delete the card type, save the configuration and then re-add the card type to the new desired position.")
      return false
    end
    true
  end

  def card_defaults_to_delete_relationships(deleted_card_types, deleted_relationships)
    transitions_or_card_defaults_to_delete(project.card_defaults, deleted_card_types, deleted_relationships)
  end

  def expand_view_to_delete(deleted_card_types, views = project.card_list_views)
    views.select do |view|
      view.expands.any? do |card_number|
        card = project.cards.find_by_number(card_number)
        card && deleted_card_types.include?(card.card_type)
      end
    end
  end

  def transitions_to_delete(deleted_card_types, deleted_relationships)
    transitions_or_card_defaults_to_delete(project.transitions, deleted_card_types, deleted_relationships)
  end

  def update_remove_from_tree_values(deleted_card_types)
    if deleted_card_types.include?(bottom_card_type)
      second_to_bottom_card_type = all_card_types[-2]
      transitions_to_check = project.transitions.find_all_by_card_type_id(second_to_bottom_card_type.id)
      transitions_to_check.each do |transition|
        remove_from_this_tree_with_children_action = transition.actions.detect { |transition_action| transition_action.is_a?(RemoveFromTreeTransitionAction) &&
                                                                                                     transition_action.tree_configuration == self &&
                                                                                                     transition_action.value == TreeBelongingPropertyDefinition::WITH_CHILDREN_VALUE }
        if remove_from_this_tree_with_children_action
          remove_from_this_tree_with_children_action.value = TreeBelongingPropertyDefinition::JUST_THIS_CARD_VALUE
          remove_from_this_tree_with_children_action.save
        end
      end
    end
  end

  def transitions_or_card_defaults_to_delete(transitions_or_card_defaults, deleted_card_types, deleted_relationships)
    transitions_or_card_defaults.select do |t|
      transition_uses_deleted_relationship(t, deleted_relationships) || transition_uses_deleted_card_types(t, deleted_card_types)
    end
  end

  def transition_uses_deleted_relationship(transition, deleted_relationships)
    deleted_relationships.any? { |prop| transition.uses_property_definition?(prop) }
  end

  def transition_uses_deleted_card_types(transition, deleted_card_types)
    deleted_card_types.any? do |card_type|
      (transition.card_type == card_type && transition.has_tree_belonging_actions?(self)) ||
      card_types_before(card_type).any? do |card_type_before|
        transition.card_type_name == card_type.name && transition.uses_property_definition?(find_relationship(card_type_before))
      end
    end
  end

  def update_card_default_relationships(deleted_card_types, deleted_relationships)
    project.card_defaults.select do |cd|
      deleted_relationships.each { |relationship| cd.stop_using_property_definition(relationship) }
      deleted_card_types.any? do |card_type|
        card_types_before(card_type).any? do |card_type_before|
          pd = find_relationship(card_type_before)
          if (cd.card_type_name == card_type.name && cd.uses_property_definition?(pd))
            cd.stop_using_property_definition(pd)
          end
        end
      end
    end
  end

  def aggregates_to_delete(deleted_card_types)
    bottom_card_type_is_being_deleted = deleted_card_types.include?(bottom_card_type)
    aggregates = []
    aggregate_property_definitions.each do |aggregate_prop_def|
      is_on_level_being_deleted = deleted_card_types.collect(&:id).include?(aggregate_prop_def.aggregate_card_type_id)
      is_aggregating_only_deleted_card_type = deleted_card_types.collect(&:id).include?(aggregate_prop_def.aggregate_scope_card_type_id)
      is_on_parent_of_bottom_card_type = (aggregate_prop_def.aggregate_card_type == previous_card_type(bottom_card_type))
      aggregates << aggregate_prop_def if is_on_level_being_deleted || is_aggregating_only_deleted_card_type || (is_on_parent_of_bottom_card_type && bottom_card_type_is_being_deleted)
    end
    aggregates
  end

  def remove_cards_of_type(card_type)
    removed_cards = CardQuery.new(:conditions => CardQuery::SqlCondition.new(["LOWER(#{Card.quoted_table_name}.card_type_name) = ?", card_type.name.downcase]))
    set_properties_to_nil(removed_cards, relationship_map, {:bypass_update_aggregates => true, :bypass_versioning => false})
    set_properties_to_nil(removed_cards, aggregate_property_definitions, {:bypass_update_aggregates => true, :bypass_versioning => true})

    tree_belongings.delete_all_from_type(card_type, self)
  end

  def roll_up_containings(card, card_type=nil)
    card_type ||= card.card_type
    if containmship = relationship_map.relationship_for_card_type(card_type)
      containmship.replace_values(card.id, nil)
    end
  end

  def bottom_card_type
    all_card_types.last
  end
end
