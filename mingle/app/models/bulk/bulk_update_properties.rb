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

module Bulk
  class BulkUpdateProperties
    include SqlHelper, CardsChanger

    attr_reader :errors

    def initialize(project, card_id_criteria)
      @project = project
      @card_id_criteria = card_id_criteria
      @errors = []
      @bulk_update_tool = BulkUpdateTool.new(@project)
    end

    def update_properties(property_and_values, options = {})
      property_and_values = PropertyAndValues.new(@project, property_and_values)

      return if property_and_values.empty?
      return unless update_properties_valid?(property_and_values, options)
      prop_def_columns = property_and_values.property_column_names
      prop_def_values = property_and_values.values

      affected_formula_properties = FormulaPropertiesToUpdate.new(@project, property_and_values, @card_id_criteria, options)

      if options[:bypass_versioning] && affected_formula_properties.any?
        options[:bypass_versioning] = false
      end

      begin
        with_update_aggregates(property_and_values.property_definitions, affected_formula_properties, options) do
          if options[:change_version]
            update_version(prop_def_columns, prop_def_values, options[:change_version], affected_formula_properties)
          else
            create_card_versions(property_and_values, affected_formula_properties, options)
          end

          update_search_index(property_and_values) # doing update index first may have potential problem even in asynchroize env. Change it to observer#before_update update observer#after_update style as soon as possible
          update_properties_in_db(property_and_values, affected_formula_properties, options)
          notify_cards_properties_changing(@project, @card_id_criteria, property_and_values.as_map)
        end
      rescue Exception => e
        @errors << "Update card properties has failed unexpectedly.  Please try again."
        @project.logger.error("\nUnable to bulk update properties #{prop_def_columns.join(', ')} to values #{prop_def_values.join(', ')}.\n\nRoot cause of error #{e}:\n#{e.backtrace.join("\n")}\n")
        raise e
      end
    end

    private

    def update_properties_valid?(property_and_values, options)
      return true if options[:bypass_update_properties_validation]
      #todo we need to refactor the following validation to use property_value.assign_to(card) and create the card by the property_value#property_definition#card_types.first instead of project.card_types.first which maybe not available to the property_value#property_definition
      validator_card = Card.new(:name => 'any_name', :project_id => @project.id, :card_type_name => @project.card_types.first.name)
      validator_card.update_properties(property_and_values.as_map)
      if !validator_card.errors.empty? || !validator_card.valid?
        @errors += validator_card.errors.full_messages
        return false
      end
      true
    end

    def update_search_index(property_and_values)
      prop_def_columns_not_equal = property_and_values.map { |prop_def, computed_value| not_equal_condition(prop_def.column_name, computed_value) }
      @bulk_update_tool.update_search_index("id #{@card_id_criteria.to_sql} AND (#{prop_def_columns_not_equal.join(' OR ')})")
    end

    def update_properties_in_db(property_and_values, affected_formula_properties, options)
      ids = @card_id_criteria.to_sql
      unless options[:bypass_versioning] || (property_and_values.only_involving_aggregates? && affected_formula_properties.empty?)
        property_other_than_aggregate_has_changed = (property_and_values.properties_have_changed_conditions(:exclude_aggregates => true) + affected_formula_properties.formula_values_have_changed_conditions).join(' OR ')
        connection.bulk_update(:table => Card.table_name, :set => "version = version + 1", :for_ids => ids, :where => property_other_than_aggregate_has_changed)
      end

      setters = property_and_values.as_setters.merge({ 'modified_by_user_id' => User.current.id, 'updated_at' => connection.datetime_insert_sql(Clock.now) })
      set = setters.collect { |col, val| "#{quote_column_name col} = #{val}"}.join(", ")

      a_property_has_changed = (property_and_values.properties_have_changed_conditions + affected_formula_properties.formula_values_have_changed_conditions).join(' OR ')
      connection.bulk_update(:table => Card.table_name, :set => set, :for_ids => ids, :where => a_property_has_changed)

      CardCachingStamp.update("id #{ids}") if options[:increment_caching_stamp]
      affected_formula_properties.update(ids)
    end

    def create_card_versions(property_and_values, affected_formula_properties, options)
      return if options[:bypass_versioning]

      setters = property_and_values.as_setters.dup
      setters['comment'] = sanitize_sql("?", options[:comment]) if options[:comment]
      setters['system_generated_comment'] = sanitize_sql("?", options[:system_generated_comment]) if options[:system_generated_comment]

      properties_have_changed = (property_and_values.properties_have_changed_conditions(:exclude_aggregates => true) + affected_formula_properties.formula_values_have_changed_conditions).join(' OR ')

      @bulk_update_tool.card_versioning.create_card_versions("?.id #{@card_id_criteria.to_sql} AND (#{properties_have_changed})", setters)
      affected_formula_properties.update_formulas_in_versions(properties_have_changed)
    end

    # This method, which you shouldn't be using anyway, needs a card_id_criteria pointing to just one card.
    # It updates properties on that single version -- that's right, it changes a version that has already been created.
    def update_version(prop_def_columns, prop_def_values, version, affected_formula_properties)
      card_id_criteria = @card_id_criteria
      TemporaryIdStorage.with_session do |session_id|
        insert_sql = %{ INSERT INTO #{TemporaryIdStorage.table_name} (session_id, id_1)
                      SELECT '#{session_id}', #{Card.quoted_versioned_table_name}.id
                       FROM #{Card.quoted_versioned_table_name}
                       WHERE #{Card.quoted_versioned_table_name}.version = #{version} AND
                             #{Card.quoted_versioned_table_name}.card_id IN (SELECT id FROM #{Card.quoted_table_name} WHERE id #{card_id_criteria.to_sql})
                    }
        execute(insert_sql)

        prop_def_columns_equal = []
        prop_def_columns.each_with_index do |column_name, index|
          prop_def = @project.property_definitions_including_type(:include_hidden => true).detect {|pd| pd.column_name == column_name}
          if prop_def.formulaic?
            prop_def_columns_equal << (prop_def_values[index] ? "#{column_name} = #{prop_def_values[index]}" : "#{column_name} = NULL")
          else
            prop_def_columns_equal << sanitize_sql("#{column_name} = ?", prop_def_values[index])
          end
        end

        update_cards_sql = %{ UPDATE #{Card.quoted_versioned_table_name}
                              SET version = version, modified_by_user_id = modified_by_user_id, updated_at = updated_at, #{prop_def_columns_equal.join(',')}
                              WHERE id in (SELECT t.id_1 FROM #{TemporaryIdStorage.table_name} t where session_id = '#{session_id}')
                            }
        execute(update_cards_sql)

        versions_to_update_condition = "IN (SELECT t.id_1 FROM #{TemporaryIdStorage.table_name} t where session_id = '#{session_id}')"
        affected_formula_properties.update_versions_table(versions_to_update_condition)
        regenerate_changes(card_id_criteria, version)
      end
    end

    def regenerate_changes(card_id_criteria, version_number)
      changed_version = Card::Version.find(:first, :conditions => ["card_id #{card_id_criteria.to_sql} AND version = ?", version_number])
      if event = changed_version.event
        Event.lock_and_generate_changes!(event.id)
      else
        changed_version.create_event
      end
    end

    def with_update_aggregates(property_definitions, affected_formula_properties, options, &block)
      aggregates_to_update = options[:bypass_update_aggregates] ? [] : find_aggregates_to_update(property_definitions, affected_formula_properties)

      if aggregates_to_update.any?
        card = Card.find(:first, :conditions => ["id #{@card_id_criteria.to_sql}"])
        tree_ids_for_aggregates = aggregates_to_update.map(&:tree_configuration_id)
        relevant_tree_configurations = card.tree_configurations(:conditions => ["tree_configurations.id in (?)", tree_ids_for_aggregates])

        relevant_tree_configurations.each do |tree_config|
          tree_config.compute_aggregates_for_unique_ancestors(@card_id_criteria)
        end
      end

      yield
    end

    def find_aggregates_to_update(property_definitions, affected_formula_properties)
      properties = property_definitions.reject { |pd| pd.is_a?(CardTypeDefinition) }

      potential_aggregate_targets = properties + affected_formula_properties.property_definitions
      return [] if potential_aggregate_targets.empty?

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

      aggregate_property_definitions = AggregatePropertyDefinition.find(agg_prop_def_ids.uniq)
      aggregate_property_definitions = aggregate_property_definitions.select do |agg_prop_def|
        agg_prop_def.associated_property_definitions.any? { |pd| potential_aggregate_targets.include?(pd) }
      end
      aggregate_property_definitions - properties
    end

  end

  class FormulaPropertiesToUpdate
    include SqlHelper

    def initialize(project, property_and_values, card_id_criteria, options = {})
      @project = project
      @property_and_values = property_and_values
      @options = options
      @card_id_criteria = card_id_criteria
      @bulk_update_tool = BulkUpdateTool.new(@project)
      formula_property_definitions_to_update
    end

    def update(ids)
      reset_formula_columns_to_null_in_db_update_parameters = @options[:reset_formula_columns_to_null_in_db_update_parameters]
      connection.bulk_update(reset_formula_columns_to_null_in_db_update_parameters) unless reset_formula_columns_to_null_in_db_update_parameters.blank?
      formula_property_sql_string = formula_property_definitions_to_update.collect { |prop_def| prop_def.update_property_sql }.join(', ')
      unless formula_property_sql_string.blank?
        bulk_update_parameters = { :table => Card.table_name, :set => formula_property_sql_string }
        bulk_update_parameters.merge!(:for_ids => ids) if reset_formula_columns_to_null_in_db_update_parameters.blank?
        connection.bulk_update(bulk_update_parameters)
        nil_out_nonapplicable_formulas(Card.table_name, ids)
      end
    end

    def any?
      formula_property_definitions_to_update.any?
    end

    def empty?
      !any?
    end

    def property_definitions
      formula_property_definitions_to_update
    end

    def formula_property_definitions_to_update
      formula_property_ids_applicable_to_cards_being_updated = if @property_and_values.only_involving_aggregates?
        @property_and_values.property_definitions.map(&:dependant_formulas).flatten.compact.uniq
      else
        find_formula_property_ids_for_all_card_types_in_card_selection
      end
      formula_properties_applicable_to_cards_being_updated = PropertyDefinition.find(:all, :conditions => ['id IN (?)', formula_property_ids_applicable_to_cards_being_updated])
      formula_properties_applicable_to_cards_being_updated - @property_and_values.property_definitions_being_set_to_nil
    end
    memoize :formula_property_definitions_to_update

    def update_formulas_in_versions(prop_def_columns_with_not_equal)
      return if formula_property_definitions_to_update.empty?
      TemporaryIdStorage.with_session do |session_id|
        connection.insert_into(:table => TemporaryIdStorage.table_name,
                               :insert_columns => ['session_id', 'id_1'],
                               :select_columns => ["'#{session_id}'", "#{Card.quoted_table_name}.id"],
                               :from => Card.quoted_table_name,
                               :where => "id #{@card_id_criteria.to_sql} AND (#{prop_def_columns_with_not_equal})",
                               :generate_id => false)

        versions_to_update_condition = %{
          IN (SELECT version_id_to_update
             FROM (
               SELECT MAX(#{Card.quoted_versioned_table_name}.id) AS version_id_to_update, MAX(#{Card.quoted_versioned_table_name}.version)
               FROM #{Card.quoted_versioned_table_name}
               JOIN #{Card.quoted_table_name} ON (#{Card.quoted_table_name}.id = #{Card.quoted_versioned_table_name}.card_id)
               WHERE card_id IN (SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{session_id}')
               GROUP BY #{Card.quoted_versioned_table_name}.#{quote_column_name 'number'}
             ) latest_versions)
        }

        update_versions_table(versions_to_update_condition)
      end
    end

    def update_versions_table(versions_to_update_condition)
      formula_property_sql_string = card_version_formula_update_sql
      return if formula_property_sql_string.blank?
      connection.bulk_update(:table => Card.versioned_table_name,
                             :set => formula_property_sql_string,
                             :for_ids => versions_to_update_condition)
      nil_out_nonapplicable_formulas(Card.versioned_table_name, versions_to_update_condition)
    end

    def formula_values_have_changed_conditions
      property_definitions.map do |pd|
        formula = pd.formula
        column_vs_column_not_equal_condition(formula.to_sql(Card.table_name), formula.to_sql(Card.table_name, false, @property_and_values.as_pd_map))
      end
    end
    memoize :formula_values_have_changed_conditions

    private

    def card_version_formula_update_sql
      property_definitions.collect { |prop_def| prop_def.update_property_sql(Card.versioned_table_name) }.join(', ')
    end

    def nil_out_nonapplicable_formulas(table_name, id_condition)
      card_types = @bulk_update_tool.card_types_from_selected_cards(@card_id_criteria)
      card_types.each do |card_type|
        formulas_to_nil_out = self.property_definitions.reject { |pd| pd.card_types.include?(card_type) }
        if formulas_to_nil_out.any?
          connection.bulk_update(:table => table_name,
                                 :set => formulas_to_nil_out.collect{|pd| "#{pd.column_name} = NULL"}.join(','),
                                 :for_ids => id_condition,
                                 :where => sanitize_sql(%{ LOWER(card_type_name) = LOWER(?) }, card_type.name))
        end
      end
    end

    def find_formula_property_ids_for_all_card_types_in_card_selection
      sql = SqlHelper.sanitize_sql(%{
        SELECT DISTINCT pd.id
        FROM property_definitions pd
        JOIN property_type_mappings ctpd ON (ctpd.property_definition_id = pd.id)
        JOIN card_types ct ON (ctpd.card_type_id = ct.id)
        WHERE pd.type = ?
        AND ct.name IN (SELECT DISTINCT card_type_name from #{Card.quoted_table_name} WHERE id #{@card_id_criteria.to_sql})
        AND pd.project_id = ?
      }, FormulaPropertyDefinition.name, @project.id)
      connection.select_values(sql)
    end

  end

  class PropertyAndValues
    include SqlHelper, Enumerable
    attr_reader :property_definitions

    def initialize(project, property_and_values)
      property_and_values.reject! { |key, value| value == CardSelection::MIXED_VALUE }
      @property_and_values = turn_keys_into_property_definitions(project, property_and_values)
      @property_definitions = @property_and_values.keys
    end

    def empty?
      @property_definitions.empty?
    end

    def values
      @property_definitions.collect do |prop_def|
        value = @property_and_values[prop_def]
        prop_def.calculated? ? value : prop_def.property_value_from_db(value).computed_value
      end
    end
    memoize :values

    def as_map
      ({}).tap do |map|
        @property_and_values.each { |property_definition, value| map[property_definition.name] = value }
      end
    end

    def as_pd_map
      @property_and_values
    end

    def property_column_names
      @property_definitions.collect { |prop_def| prop_def.column_name }
    end

    def property_definitions_being_set_to_nil
      @property_definitions.select { |pd| @property_and_values[pd].nil? }
    end

    def only_involving_aggregates?
      @property_definitions.all? { |pd| pd.aggregated? }
    end

    def each(&block)
      prop_def_to_computed_values.each(&block)
    end

    def as_setters
      prop_def_to_computed_values.inject({}) do |setters, (prop_def, computed_value)|
        should_sanitize_sql = !prop_def.formulaic?
        value = should_sanitize_sql ? computed_value : (computed_value || 'NULL')
        setters[prop_def.column_name] = should_sanitize_sql ? sanitize_sql("?", value) : value
        setters
      end
    end
    memoize :as_setters

    def properties_have_changed_conditions(options = { :exclude_aggregates => false })
      prop_def_columns_not_equal = []
      prop_def_to_computed_values.each do |prop_def, computed_value|
        next if options[:exclude_aggregates] && prop_def.aggregated?
        column_name = prop_def.column_name
        prop_def_columns_not_equal << if prop_def.formulaic?
          formula_not_equal_condition(column_name, computed_value)
        else
          column_name.downcase == 'card_type_name' ? not_equal_condition(column_name, computed_value, :case_insensitive => true) : not_equal_condition(column_name, computed_value)
        end
      end
      prop_def_columns_not_equal
    end

    private

    def prop_def_to_computed_values
      Hash[*@property_definitions.zip(values).flatten]
    end
    memoize :prop_def_to_computed_values

    def turn_keys_into_property_definitions(project, property_and_values)
      property_and_values_with_prop_def_keys = {}
      property_and_values.each do |property, value|
        prop_def = project.reload.find_property_definition_including_card_type_def(property, :with_hidden => true)
        property_and_values_with_prop_def_keys[prop_def] = value unless prop_def.nil?
      end
      property_and_values_with_prop_def_keys
    end
  end

end


