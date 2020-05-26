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
  class BulkDestroy
    include SecureRandomHelper, SqlHelper, CardsChanger

    def initialize(project, card_id_criteria)
      @project = project
      @card_id_criteria = card_id_criteria
    end

    def run(options)
      with_card_ids_table do |cards_table|

        cards_table.update_relationship_properties_that_use_these_cards(:with_card_relationship_properties_in_project)
        cards_table.update_relationship_properties_that_use_these_cards(:with_tree_relationship_properties_in_project)
        cards_table.numbers.each do |card_number|
          execute("DELETE FROM #{HistorySubscription.table_name} WHERE hashed_filter_params = '#{HistorySubscription.param_hash("card_number=#{card_number}")}' AND project_id = #{@project.id}")
        end
        cards_table.update_project_level_variables
        cards_table.recompute_aggregates
        execute("DELETE FROM #{TreeBelonging.table_name} WHERE card_id IN (#{cards_table.select_ids_sql})")

        murmurs_originating_from_cards_sql = %{
          SELECT id
          FROM #{Murmur.table_name}
          WHERE type='#{CardCommentMurmur.name}'
          AND origin_type = '#{Card.name}'
          AND origin_id IN (#{cards_table.select_ids_sql})
        }
        murmurs_originating_from_cards_ids = connection.select_values(murmurs_originating_from_cards_sql)
        CardCommentMurmur.invalidate_murmur_cache(@project.id, murmurs_originating_from_cards_ids)

        select_card_ids = "IN (SELECT #{Card.quoted_table_name}.id FROM #{Card.quoted_table_name} WHERE #{Card.quoted_table_name}.id #{@card_id_criteria.to_sql})"
        connection.bulk_update(:table => Murmur.table_name, :set => "origin_id=NULL, origin_type=NULL", :for_origin_ids => select_card_ids, :where => "origin_type = 'Card' AND project_id = #{@project.id}")
        FullTextSearch.index_bulk_murmurs(@project, murmurs_originating_from_cards_ids)

        if options[:include_associations_rails_knows_about]
          cards_table.destroying_ids.each do |card_id|
            Card.find(card_id).destroy_dependencies
          end
        end

        if options[:include_associations_rails_knows_about]
          sql = "SELECT id FROM #{Card.quoted_table_name} WHERE #{Card.quoted_table_name}.id #{@card_id_criteria.to_sql} ORDER BY id DESC"
          card_ids = @project.connection.select_values(sql)
          Card.deindex(card_ids, @project.search_index_name)

          connection.delete_from(:table => Attaching.table_name, :for_attachable_ids => select_card_ids, :where => "attachable_type = 'Card'")
          connection.delete_from(:table => Tagging.table_name, :for_taggable_ids => select_card_ids, :where => "taggable_type = 'Card'")
          connection.delete_from(:table => CardRevisionLink.table_name, :for_card_ids => select_card_ids, :where => "project_id = #{@project.id}")
          Bulk::BulkVersioning.new(@project).create_deletion_versions("#{Card::quoted_table_name}.id #{select_card_ids}")
        end

        if options[:include_associations_rails_knows_about]
          notify_before_cards_destroy(@project, @card_id_criteria)
          connection.delete_from(:table => Card.table_name, :for_ids => "IN (#{cards_table.select_ids_sql})")
        end

        return true
      end
    end

    def warnings
      ({:belongs_to_trees => [],
                 :card_relationship => {:usage_count => 0, :properties => []},
                 :tree_relationship => {:usage_count => 0, :properties => []},
                 :items_that_will_be_deleted => {:favorites => [], :tabbed_views => [], :transitions => []},
                 :values_that_will_be_not_set => {:project_variables => []}}).tap do |warnings|
        with_card_ids_table do |cards_table|
          cards_table.with_card_relationship_properties_in_project do |card_relationship_property_definition_ids, card_relationship_property_definition_ids_sql|
            if card_relationship_property_definition_ids.size > 0
              warnings[:card_relationship] = cards_table.relationship_properties_warning(:select_card_relationship_properties_in_project)
            end
            warnings[:items_that_will_be_deleted][:transitions] = cards_table.transitions_that_will_be_deleted(card_relationship_property_definition_ids_sql)
          end
          cards_table.with_tree_relationship_properties_in_project do |tree_relationship_property_definition_ids, tree_relationship_property_definition_ids_sql|
            if tree_relationship_property_definition_ids.size > 0
              warnings[:tree_relationship] = cards_table.relationship_properties_warning(:select_tree_relationship_properties_in_project)
            end
            warnings[:items_that_will_be_deleted][:transitions] += cards_table.transitions_that_will_be_deleted(tree_relationship_property_definition_ids_sql)
            warnings[:items_that_will_be_deleted][:transitions].uniq!
          end
          warnings[:belongs_to_trees] = cards_table.belongs_to_tree_names
          warnings[:values_that_will_be_not_set][:project_variables] = cards_table.project_variables_that_will_be_deleted
        end
      end
    end

    def project
      @project
    end

    private
    def with_card_ids_table
      TemporaryIdStorage.with_session do |session_id|
        connection.insert_into(:table => TemporaryIdStorage.table_name,
                               :insert_columns => ['session_id', 'id_1'],
                               :select_columns => ["'#{session_id}'", "#{Card.quoted_table_name}.id"],
                               :from => Card.quoted_table_name,
                               :where => "id #{@card_id_criteria.to_sql}",
                               :generate_id => false)
        yield CardsInTempTableState.new(@project, session_id, @card_id_criteria)
      end
    end

    class CardsInTempTableState
      include SqlHelper

      def initialize(project, session_id, card_id_criteria)
        @project = project
        @session_id = session_id
        @sql = "SELECT cid.id_1 FROM #{TemporaryIdStorage.table_name} cid WHERE cid.session_id = '#{session_id}'"
        @card_id_criteria = card_id_criteria
      end

      def select_ids_sql
        @sql
      end

      def numbers
        @card_numbers ||= connection.select_values("SELECT #{quote_column_name 'number'} FROM #{Card.quoted_table_name} WHERE id IN (#{select_ids_sql})")
      end

      def belongs_to_tree_names
        find_tree_configurations_sql = "SELECT distinct tc.name FROM #{TreeConfiguration.table_name} tc inner join #{TreeBelonging.table_name} tb ON tb.tree_configuration_id=tc.id WHERE tb.card_id in (#{select_ids_sql})"
        connection.select_values(find_tree_configurations_sql)
      end

      def recompute_aggregates
        self.belongs_to_tree_names.each do |tree_name|
          tree_configuration = @project.tree_configurations.find_by_name(tree_name)
          BulkUpdateTool.new(@project).compute_aggregates(tree_configuration, @card_id_criteria)
        end
      end

      def delete_views_associated_with_these_cards
        card_list_views_to_delete.each(&:destroy)
      end

      def card_list_views_to_delete
        @project.card_list_views.select do |card_view|
          delete_this_view = false
          cards_used_in_view_as_sql = card_view.cards_used_sql_condition
          unless cards_used_in_view_as_sql.blank?
            matching_cards_in_view_sql = "SELECT COUNT(*) FROM #{Card.quoted_table_name} WHERE project_id = #{Project.current.id} AND (#{cards_used_in_view_as_sql}) AND id IN (#{select_ids_sql})"
            delete_this_view = 0 < select_value(matching_cards_in_view_sql).to_i
          end

          unless delete_this_view
            plvs_used = card_view.project_variables_used.collect(&:name)
            plvs_that_will_be_deleted = project_variables_that_will_be_deleted
            delete_this_view = plvs_that_will_be_deleted - plvs_used != plvs_that_will_be_deleted
          end

          delete_this_view
        end
      end

      def exists_ids_sql(comparison_column)
        "EXISTS (SELECT 1 FROM #{TemporaryIdStorage.table_name} cid WHERE cid.session_id = '#{@session_id}' and cid.id_1 = #{comparison_column})"
      end

      def relationship_properties_warning(select_relationship_properties_in_project)
        relationship_records = connection.select_all(send(select_relationship_properties_in_project, 'column_name, name'))

        ({}).tap do |warning|
          warning[:usage_count] = 0
          warning[:properties] = relationship_records.collect do |record|
            sql = "SELECT COUNT(*) FROM #{Card.quoted_table_name} WHERE NOT #{exists_ids_sql("id")} AND #{exists_ids_sql(record['column_name'])}"
            usage_count = select_value(sql).to_i
            warning[:usage_count] += usage_count
            usage_count > 0 ? record['name'] : nil
          end.compact.sort
        end
      end

      def transitions_that_will_be_deleted(relationship_property_definition_ids_sql)
        ([]).tap do |transition_names|
          with_transitions_that_will_be_deleted(relationship_property_definition_ids_sql) do |transition_ids_to_delete_sql|
            transition_names << connection.select_values("SELECT name FROM #{Transition.table_name} WHERE id IN (#{transition_ids_to_delete_sql})")
          end
        end.flatten
      end

      def project_variables_that_will_be_deleted
        connection.select_values("SELECT name FROM #{ProjectVariable.table_name} #{project_variables_where_clause}")
      end
      memoize :project_variables_that_will_be_deleted

      def update_project_level_variables
        update_value_sql = %{
          UPDATE #{ProjectVariable.table_name}
          SET value = NULL
          #{project_variables_where_clause}
        }
        execute(update_value_sql)
      end

      def with_card_relationship_properties_in_project
        sql = select_card_relationship_properties_in_project('id')
        ids = connection.select_values(sql)
        yield(ids, sql)
      end

      def with_tree_relationship_properties_in_project
        sql = select_tree_relationship_properties_in_project('id')
        ids = connection.select_values(sql)
        yield(ids, sql)
      end

      def update_relationship_properties_that_use_these_cards(with_method)
        send(with_method) do |relationship_property_definition_ids, relationship_property_definition_ids_sql|
          if (relationship_property_definition_ids.size > 0)
            relationship_property_definition_ids_sql = relationship_property_definition_ids.join(', ')
            update_card_default_relationship_properties(relationship_property_definition_ids_sql)
            update_cards_using_any_card_in_the_selection_as_value_of_relationship_property_definitions(relationship_property_definition_ids_sql)
          end
          update_transition_relationship_properties(relationship_property_definition_ids_sql)
        end
      end

      def destroying_ids
        @destroying_ids ||= connection.select_values(select_ids_sql)
      end

      private
      def in_ids_list_sql_cast_as_string
        "SELECT #{as_char("id_1")} FROM (#{in_ids_list_sql}) ids"
      end
      def in_ids_list_sql
        select_ids_sql
      end
      def select_card_relationship_properties_in_project(column)
        "SELECT #{column} FROM #{PropertyDefinition.table_name} WHERE type = 'CardRelationshipPropertyDefinition' and project_id = #{@project.id}"
      end

      def select_tree_relationship_properties_in_project(column)
        "SELECT #{column} FROM #{PropertyDefinition.table_name} WHERE type = 'TreeRelationshipPropertyDefinition' and project_id = #{@project.id}"
      end

      # TODO: Obviously, this is very similar to project_variables_that_will_be_deleted.... stop hitting the database so much.
      def project_variables_ids_that_will_be_deleted
        connection.select_values("SELECT id FROM #{ProjectVariable.table_name} #{project_variables_where_clause}")
      end

      def update_cards_using_any_card_in_the_selection_as_value_of_relationship_property_definitions(card_relationship_property_definition_ids_sql)
        mql_numbers_list = numbers.join(', ')
        update_property_definitions = connection.select_all("SELECT name, column_name FROM #{PropertyDefinition.table_name} WHERE id IN (#{card_relationship_property_definition_ids_sql})")
        update_property_definitions.each do |row|
          card_numbers_to_reset = connection.select_values("SELECT #{quote_column_name 'number'} FROM #{Card.quoted_table_name} WHERE #{row['column_name']} IN (#{select_ids_sql}) AND id NOT IN (#{in_ids_list_sql})")
          if card_numbers_to_reset.any?
            property_to_reset = { row['name'] => nil }
            CardSelection.new(@project, CardQuery.parse("WHERE NUMBER IN (#{card_numbers_to_reset.join(',')})")).update_properties(property_to_reset)
          end
        end
      end

      def project_variables_where_clause
        %{
          WHERE data_type = '#{ProjectVariable::CARD_DATA_TYPE}' AND
              #{not_null_or_empty('value')} AND
              project_id = #{@project.id} AND
              #{as_integer('value')} IN (#{in_ids_list_sql})
        }
      end

      def with_transitions_that_will_be_deleted(relationship_property_definition_ids_sql)
        return if destroying_ids.blank?
        additional_clauses = ["(property_definition_id IN (#{relationship_property_definition_ids_sql}) AND value IN (#{in_ids_list_sql_cast_as_string}))"]
        project_variable_ids = project_variables_ids_that_will_be_deleted
        variable_binding_ids = variable_binding_ids_that_will_be_deleted(project_variable_ids)
        additional_clauses << "project_variable_id IN (#{project_variable_ids.join(', ')})" if project_variable_ids.any?
        prerequisite_transition_ids_using_these_cards_sql = %{
          SELECT transition_id
          FROM #{TransitionPrerequisite.table_name}
          WHERE type = 'HasSpecificValue' AND
                (#{additional_clauses.join(' OR ')})
        }
        transition_ids_to_delete = connection.select_values(prerequisite_transition_ids_using_these_cards_sql)

        from_transition_actions = transition_actions_with_card_relationship_properties_set_to_cards_being_deleted_sql('Transition', relationship_property_definition_ids_sql, variable_binding_ids)
        action_transition_ids_using_these_cards_sql = "SELECT executor_id #{from_transition_actions}"
        transition_ids_to_delete.concat(connection.select_values(action_transition_ids_using_these_cards_sql))

        if (transition_ids_to_delete.size > 0)
          transition_ids_to_delete_sql = transition_ids_to_delete.join(', ')
          yield(transition_ids_to_delete_sql)
        end
      end

      def variable_binding_ids_that_will_be_deleted(project_variable_ids)
        connection.select_values("SELECT id FROM #{VariableBinding.table_name} WHERE project_variable_id IN (#{project_variable_ids.join(', ')})") if project_variable_ids.any?
      end

      def update_transition_relationship_properties(relationship_property_definition_ids_sql)
        with_transitions_that_will_be_deleted(relationship_property_definition_ids_sql) do |transition_ids_to_delete_sql|
          execute("DELETE FROM #{TransitionPrerequisite.table_name} WHERE transition_id IN (#{transition_ids_to_delete_sql})")
          execute("DELETE FROM #{TransitionAction.table_name}       WHERE executor_id   IN (#{transition_ids_to_delete_sql}) AND executor_type = 'Transition'")
          execute("DELETE FROM #{Transition.table_name}             WHERE id            IN (#{transition_ids_to_delete_sql})")
        end
      end

      def update_card_default_relationship_properties(relationship_property_definition_ids_sql)
        execute("DELETE #{transition_actions_with_card_relationship_properties_set_to_cards_being_deleted_sql('CardDefaults', relationship_property_definition_ids_sql, [])}")
      end

      def transition_actions_with_card_relationship_properties_set_to_cards_being_deleted_sql(executor_type, relationship_property_definition_ids_sql, variable_binding_ids)
        card_relationship_property_clause = "(target_id IN (#{relationship_property_definition_ids_sql}) AND value IN (#{in_ids_list_sql_cast_as_string}))"
        additional_clauses = [card_relationship_property_clause]
        additional_clauses << "variable_binding_id IN (#{variable_binding_ids.join(', ')})" if !variable_binding_ids.nil? && !variable_binding_ids.empty?
        %{
          FROM #{TransitionAction.table_name}
          WHERE type = 'PropertyDefinitionTransitionAction' AND
                executor_type = '#{executor_type}' AND
                (#{additional_clauses.join(' OR ')})
        }
      end
    end
  end
end
