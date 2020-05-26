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

class CardSelection
  include SecureRandomHelper, SqlHelper
  attr_accessor :errors, :update_count

  MIXED_VALUE = ':mixed_value'

  def initialize(project, cards_or_view_or_query)
    self.errors = []
    self.update_count = 0
    @project = project

    @card_id_criteria =  if cards_or_view_or_query.respond_to?(:has_conditions) && cards_or_view_or_query.respond_to?(:to_conditions)
      card_query_to_criteria(cards_or_view_or_query)
    elsif cards_or_view_or_query.respond_to?(:as_card_query)
      card_query_to_criteria(cards_or_view_or_query.as_card_query)
    else
      if (!cards_or_view_or_query.nil? && cards_or_view_or_query.size > 0)
        CardIdCriteria.from_cards(cards_or_view_or_query)
      else
        CardIdCriteria.no_cards_criteria
      end
    end
  end

  def self.cards_from(project, card_ids)
    return [] if card_ids.nil?
    ids = card_ids.respond_to?(:join) ? card_ids : card_ids.split(',')
    project.cards.find(:all, :conditions => ["#{Card.quoted_table_name}.id in (?)", ids], :include => {:taggings => :tag})
  end

  def value_for(property_definition)
    query_result = values_from_cards(property_definition)
    if query_result.size > 1
      return ['(mixed value)', MIXED_VALUE]
    else
      property_value = PropertyValue.create_from_db_identifier(property_definition, query_result.first)
      property_value.db_value_pair
    end
  end

  def mixed_value?(property_definition)
    return values_from_cards(property_definition).size > 1
  end

  def display_value_for(property_definition)
    name_value_pair_for(property_definition, &:first)
  end

  def value_identifier_for(property_definition)
    name_value_pair_for(property_definition, &:last)
  end

  def update_property(property_name, value)
    relationship = @project.find_property_definition_or_nil(property_name, :with_hidden => true)
    if relationship && relationship.is_a?(TreeRelationshipPropertyDefinition)
      begin
        card = if value.blank?
          nil
        else
          computed = relationship.property_value_from_db(value).computed_value
          computed.nil? ? nil : @project.cards.find(computed)
        end
        update_relationship_property(relationship, card)
      rescue Exception => e
        self.errors += ["Update card properties has failed unexpectedly.  Please try again."]
        @project.logger.error("\nUnable to bulk update relationship property #{property_name} to card id #{value}.\n\nRoot cause of error #{e}:\n#{e.backtrace.join("\n")}\n")
        raise e
      end
    else
      update_properties({property_name => value})
    end
  end

  def update_properties(property_and_values, options = {})
    update_properties_card_id_criteria = @card_id_criteria
    is_card_type_change = property_and_values.keys.collect { |key| key.to_s.downcase }.include?(@project.card_type_definition.name.downcase)

    if !(card_type_change_errors = detect_attempts_to_change_type_of_cards_used_as_plv_values_or_transitions(property_and_values)).empty?
      self.errors += card_type_change_errors
      return
    end

    if is_card_type_change
      card_type_name = property_and_values.find_ignore_case(@project.card_type_definition.name)

      # we need to find some aggregates to update before we call BulkUpdateRelationships.on_card_type_change, which removes cards from trees;
      # we find and recompute other aggregates inside BulkUpdateProperties.update_properties
      aggregates_to_update = options[:bypass_update_aggregates] ? [] : aggregates_to_update_from_card_type_change
      Bulk::BulkUpdateRelationships.new(@project, @card_id_criteria).on_card_type_change(card_type_name)
      not_applicable_property_defs = @project.property_defintions_not_applicable_to_type(card_type_name)
      property_and_values.merge!(not_applicable_property_defs.inject({}){|result, property_def| result[property_def.name] = nil; result})

      bulk_card_type_change = Bulk::BulkCardTypeChange.new(@project, @card_id_criteria)
      update_properties_card_id_criteria = update_properties_card_id_criteria.and_not_in(sanitize_sql("SELECT id FROM #{Card.quoted_table_name} WHERE LOWER(card_type_name) = :card_type_name", {:card_type_name => card_type_name.downcase}))
      property_and_values.merge!(bulk_card_type_change.remove_card_from_tree_properties_and_values)
    end
    bulk_update_properties = Bulk::BulkUpdateProperties.new(@project, update_properties_card_id_criteria)
    bulk_update_properties.update_properties(property_and_values, options)
    self.errors += bulk_update_properties.errors

    #todo: this should have a better way to do it, before change, send message to update all parent cards
    #after changed, there is no parent, so should not do anything
    aggregates_to_update.each(&:update_cards) if self.errors.empty? && is_card_type_change
  end

  def tags_common_to_all
    sql = "SELECT t.id FROM #{Tagging.table_name} taggings, #{Tag.table_name} t, #{Card.quoted_table_name}
           WHERE taggings.taggable_id = #{Card.quoted_table_name}.id AND taggings.taggable_type = 'Card' AND taggings.tag_id = t.id AND #{Card.quoted_table_name}.id #{@card_id_criteria.to_sql}
           GROUP BY t.id
           HAVING COUNT(*) = #{count}"
    query_result = select_all_rows(sql)
    tag_ids = query_result.collect(&:values)
    tags = Tag.find(tag_ids.flatten)

    sort_by_name_ignore_case tags
  end

  def tags_common_to_some
    all_tags - tags_common_to_all
  end

  def remove_tag(tag_name)
    bulk_tagging_machine = Bulk::BulkTag.new(@project, @card_id_criteria)
    success = bulk_tagging_machine.remove_tag(tag_name)
    self.errors = bulk_tagging_machine.errors
    success
  end

  def tag_with(tags)
    bulk_tagging_machine = Bulk::BulkTag.new(@project, @card_id_criteria)
    success = bulk_tagging_machine.tag_with(tags)
    self.errors = bulk_tagging_machine.errors
    success
  end

  def count
    select_value("SELECT COUNT(*) FROM #{Card.quoted_table_name} WHERE id #{@card_id_criteria.to_sql}").to_i
  end

  def update_from(cards)
    @card_id_criteria = @card_id_criteria.update_from(cards)
  end

  def include?(card)
    return false if no_card_selected?
    sql = "SELECT COUNT(*) FROM #{Card.quoted_table_name} WHERE id #{@card_id_criteria.to_sql} AND id = #{card.id}"
    select_value(sql).to_i > 0
  end

  def not_in_selection(card_ids)
    # this sql says: select all cards with id in card_ids and not in the @card_id_criteria; we use the join version to satisfy Oracle
    sql = %{
      SELECT c1.* FROM #{Card.quoted_table_name} c1
      LEFT OUTER JOIN #{Card.quoted_table_name} c2 ON
        c1.id = c2.id AND c2.id IN (SELECT id FROM #{Card.quoted_table_name} WHERE id #{@card_id_criteria.to_sql})
      WHERE c2.id IS NULL AND c1.id IN (#{card_ids.join(', ')})
    }
    Card.find_by_sql(sql)
  end

  def property_definitions
    card_type_names = select_all_rows("SELECT DISTINCT card_type_name FROM #{Card.quoted_table_name} WHERE id #{@card_id_criteria.to_sql}")
    card_type_names = card_type_names.collect {|card_type_hash| card_type_hash['card_type_name']}
    return [] if card_type_names.empty?
    card_types = card_type_names.collect{|card_type_name| @project.card_types.find_by_name(card_type_name)}
    prop_defs = card_types.size > 1 ? @project.property_definitions_in_smart_order : card_types.first.property_definitions
    prop_defs.select do |prop_def|
      card_types.all?{|card_type| card_type.property_definitions.include?(prop_def)}
    end
  end

  def destroy(options={:include_associations_rails_knows_about => true})
    destroyer.run options
  end

  def warnings
    destroyer.warnings
  end

  private

  def destroyer
    Bulk::BulkDestroy.new(@project, @card_id_criteria)
  end

  def update_relationship_property(relationship, card)
    bulk_update_relationships = Bulk::BulkUpdateRelationships.new(@project, @card_id_criteria)
    bulk_update_relationships.update_relationship_property(relationship, card)
    self.errors += bulk_update_relationships.errors
  end

  def detect_attempts_to_change_type_of_cards_used_as_plv_values_or_transitions(property_and_values)
    return [] unless property_and_values.key?(@project.card_type_definition.name)
    card_type_name = property_and_values[@project.card_type_definition.name]
    detect_attempts_to_change_type_of_cards_used_as_plv_values(card_type_name) + detect_attempts_to_change_type_of_cards_used_as_transitions
  end

  def detect_attempts_to_change_type_of_cards_used_as_plv_values(card_type_name)
    #This is sensitive SQL; the joins are written in an upside down order because of how the psql
    #engine evaluates this SQL. If the joins started from plv and then joined through to cards, it will
    #attempt to cast all plv values to numbers, and fail majestically, causing a "we are sorry error".
    #If you are going to change this, please make sure to test it throughly against lots of data against both PostgreSQL and MySQL

    detect_usages_of_cards_in_selection_as_plv_values_sql = sanitize_sql %{
      SELECT usages.name, usages.card_number
      FROM
        (SELECT
            plv.name, nullif(plv.value, '') as value, c.#{quote_column_name 'number'} as card_number, c.id as card_id
          FROM
            #{Card.quoted_table_name} c
            JOIN card_types ct ON (LOWER(ct.name) = LOWER(c.card_type_name))
            JOIN project_variables plv ON (plv.card_type_id = ct.id AND plv.data_type = '#{ProjectVariable::CARD_DATA_TYPE}')
          WHERE
            plv.project_id = ?
            AND LOWER(c.card_type_name) <> LOWER(?)) usages
      WHERE
        #{connection.cast_as_integer('usages.value')} #{@card_id_criteria.to_sql(connection.cast_as_integer('usages.value'))} AND
        #{connection.cast_as_integer('usages.value')} = usages.card_id
      GROUP BY usages.name, usages.card_number
    }, @project.id, card_type_name

    usages = ActiveRecord::Base.connection.select_all(detect_usages_of_cards_in_selection_as_plv_values_sql)
    return [] unless usages && usages.any?
    plv_names = usages.collect { |plv| "(#{plv['name']})".bold }.uniq.sort
    card_numbers = usages.collect { |plv| plv['card_number'] }.uniq

    if card_numbers.size > 1
      ["Cannot change card type because some cards are being used as the value of #{'project variable'.plural(plv_names.size)}: #{plv_names.join(', ')}"]
    else
      ["Cannot change card type because card ##{card_numbers.first} is being used as the value of #{'project variable'.plural(plv_names.size)}: #{plv_names.join(', ')}"]
    end
  end

  def detect_attempts_to_change_type_of_cards_used_as_transitions
    #This is sensitive SQL; the joins are written in an upside down order because of how the psql
    #engine evaluates this SQL. If the joins started from transitions and then joined through to cards, it will
    #attempt to cast all transition_action values to numbers, and fail majestically, causing a "we are sorry error".
    #If you are going to change this, please make sure to test it throughly against lots of data against both PostgreSQL and MySQL

    detect_usages_of_cards_in_selection_as_transition_values_sql = %{
      SELECT DISTINCT usages.name
      FROM
        (SELECT
            t.name, action_cards.id AS VALUE
        FROM
          #{Card.quoted_table_name} action_cards
          JOIN card_types act  ON (LOWER(action_cards.card_type_name) = LOWER(act.name))
          JOIN property_definitions action_pd ON (act.id = action_pd.valid_card_type_id AND action_pd.type = 'TreeRelationshipPropertyDefinition')
          JOIN transition_actions ta ON (ta.target_id = action_pd.id AND ta.executor_type = 'Transition' AND
                                        (#{connection.is_number('ta.value')} AND ta.variable_binding_id IS NULL AND #{as_integer('ta.value')} = action_cards.id))
          JOIN transitions t ON (ta.executor_id = t.id)
        WHERE
          t.project_id = #{@project.id}

        UNION

        SELECT
            t.name, prereqisite_cards.id AS VALUE
        FROM
          #{Card.quoted_table_name} prereqisite_cards
          JOIN card_types pct ON (LOWER(prereqisite_cards.card_type_name) = LOWER(pct.name))
          JOIN property_definitions prerequisite_pd ON (pct.id = prerequisite_pd.valid_card_type_id AND prerequisite_pd.type = 'TreeRelationshipPropertyDefinition')
          JOIN transition_prerequisites tp ON (tp.property_definition_id = prerequisite_pd.id)
          JOIN transitions t ON (tp.transition_id = t.id)
        WHERE
          t.project_id = #{@project.id}) usages
      WHERE usages.value #{@card_id_criteria.to_sql(connection.cast_as_integer('usages.value'))}
    }

    usages = ActiveRecord::Base.connection.select_values(detect_usages_of_cards_in_selection_as_transition_values_sql).uniq.sort.bold
    return [] unless usages && usages.any?
    ["Cannot change card type because #{ usages.size > 1 ? 'some cards' : 'a card' } #{'is'.plural(usages.size)} being used in #{'transition'.plural(usages.size)}: #{usages.join(', ')}"]
  end

  def values_from_cards(property_definition)
    sql = "SELECT DISTINCT #{property_definition.column_name} FROM #{Card.quoted_table_name} WHERE id #{@card_id_criteria.to_sql}"
    connection.select_values(sql)
  end

  def no_card_selected?
    @card_id_criteria.matches_no_cards_criteria?
  end

  def name_value_pair_for(property_definition)
    value_for_property = value_for(property_definition)
    yield(value_for_property) if value_for_property
  end

  def tag_card(card, tag)
    card.add_tag(tag)
    card.errors.each_full
  end

  def all_tags
    sql = "SELECT t.id FROM #{Tagging.table_name} taggings, #{Tag.table_name} t, #{Card.quoted_table_name}
           WHERE taggings.taggable_id = #{Card.quoted_table_name}.id AND taggings.taggable_type = 'Card' AND taggings.tag_id = t.id AND #{Card.quoted_table_name}.id #{@card_id_criteria.to_sql}
           GROUP BY t.id"

    query_result = select_all_rows(sql)
    tag_ids = query_result.collect(&:values)
    tags = Tag.find(tag_ids.flatten)

    sort_by_name_ignore_case tags
  end

  def sort_by_name_ignore_case(collection)
    collection.sort_by{|element| element.name.downcase}
  end

  def card_query_to_criteria(card_query)
    CardIdCriteria.new("IN (#{card_query.to_card_id_sql})")
  end

  def aggregates_to_update_from_card_type_change
    sql = %{
      SELECT #{PropertyDefinition.table_name}.id
      FROM #{PropertyDefinition.table_name}
      WHERE #{PropertyDefinition.table_name}.type = 'AggregatePropertyDefinition' AND
            #{PropertyDefinition.table_name}.tree_configuration_id IN
              (SELECT #{TreeBelonging.table_name}.tree_configuration_id
               FROM #{TreeBelonging.table_name}
               WHERE #{TreeBelonging.table_name}.card_id #{@card_id_criteria.to_sql("#{TreeBelonging.table_name}.card_id")})
    }
    query_result = select_all_rows(sql)
    agg_prop_def_ids = query_result.collect(&:values)
    AggregatePropertyDefinition.find(agg_prop_def_ids.uniq)
  end

  def project
    @project
  end

end

