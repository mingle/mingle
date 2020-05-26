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

module DataFixes
  class RemovePropertiesWithMissingColumns < Base

    class << self

      def description
        %Q{
          Removes DB property_definition entries whose columns are missing from cards and
          card_versions tables. This situation has occasionally manifested as a result of
          table lock contention (ORA-00904).
        }
      end

      def project_ids_with_nonexistent_property_columns
        project_ids = []
        start = Time.now
        each_project do |id, identifier, cards_table, card_versions_table|
          next unless Project.connection.table_exists?(cards_table) && Project.connection.table_exists?(card_versions_table)

          missing_prop_defs_cards = fetch_prop_defs_with_nonexistent_column_names(cards_table, id)
          missing_prop_defs_card_versions = fetch_prop_defs_with_nonexistent_column_names(card_versions_table, id)

          project_ids << id unless missing_prop_defs_cards.empty? && missing_prop_defs_card_versions.empty?
        end

        Rails.logger.info("RemovePropertiesWithMissingColumns required check took: #{Time.now - start} seconds")
        project_ids
      end

      def required?
        !project_ids_with_nonexistent_property_columns.empty?
      end

      def apply(project_ids=[])
        each_project(project_ids) do |id, identifier, cards_table, card_versions_table|
          next unless Project.connection.table_exists?(cards_table) && Project.connection.table_exists?(card_versions_table)

          missing_from_cards_table = delete_property_defs(cards_table, id, identifier)
          missing_from_versions_table = delete_property_defs(card_versions_table, id, identifier)

          if missing_from_versions_table || missing_from_cards_table
            Project.find_by_identifier(identifier).with_active_project do |project|
              project.cache_key.touch_structure_key
              project.cache_key.touch_card_key
            end
          end
        end
      end

      private

      def fetch_prop_defs_with_nonexistent_column_names(table, project_id)
        get_columns_in_table_query = if ActiveRecord::Base.connection.database_vendor == :oracle
          SqlHelper.sanitize_sql(%Q{
          SELECT column_name
            FROM all_tab_cols
           WHERE UPPER(table_name) = ?
             AND UPPER(column_name) LIKE 'CP_%'
          }, table.upcase)
        else
          SqlHelper.sanitize_sql(%Q{
            SELECT UPPER(column_name)
              FROM information_schema.columns
             WHERE UPPER(table_name) = ?
               AND UPPER(column_name) LIKE 'CP_%'
          }, table.upcase)
        end

        get_property_defs_query = SqlHelper.sanitize_sql(%Q{
          SELECT id
            FROM property_definitions
           WHERE project_id = ?
             AND UPPER(column_name) NOT IN (#{get_columns_in_table_query})
        }, project_id)

        execute(get_property_defs_query).map { |c| c["id"].to_i }
      end

      def delete_property_defs(table, project_id, project_identifier)
          prop_def_ids = fetch_prop_defs_with_nonexistent_column_names(table, project_id)
          return false if prop_def_ids.empty?
          prop_def_ids.each do |pd_id|
            Rails.logger.warn "Removing property definition with id #{pd_id} from project #{project_identifier}"

            execute delete_variable_bindings(pd_id)
            execute delete_property_type_mappings(pd_id)
            execute delete_transition_actions(pd_id)
            execute delete_enumeration_values(pd_id)
            execute delete_transition_prerequisites(pd_id)
            execute delete_stale_prop_defs(pd_id)
            PropertyDefinition.delete(pd_id)

            Rails.logger.warn "-- done"
          end
          return true
      end

      def delete_variable_bindings(pd_id)
        SqlHelper.sanitize_sql(%Q{
          DELETE FROM #{t("variable_bindings")} WHERE #{c("property_definition_id")} = ?
        }, pd_id)
      end

      def delete_property_type_mappings(pd_id)
        SqlHelper.sanitize_sql(%Q{
          DELETE FROM #{t("property_type_mappings")} WHERE #{c("property_definition_id")} = ?
        }, pd_id)
      end

      def delete_transition_actions(pd_id)
        SqlHelper.sanitize_sql(%Q{
          DELETE FROM #{t("transition_actions")} WHERE #{c("target_id")} = ? AND #{c("type")} = 'PropertyDefinitionTransitionAction'
        }, pd_id)
      end

      def delete_enumeration_values(pd_id)
        SqlHelper.sanitize_sql(%Q{
          DELETE FROM #{t("enumeration_values")} WHERE #{c("property_definition_id")} = ?
        }, pd_id)
      end

      def delete_transition_prerequisites(pd_id)
        SqlHelper.sanitize_sql(%Q{
          DELETE FROM #{t("transition_prerequisites")} WHERE #{c("property_definition_id")} = ?
        }, pd_id)
      end

      def delete_stale_prop_defs(pd_id)
        SqlHelper.sanitize_sql(%Q{
          DELETE FROM #{t("stale_prop_defs")} WHERE #{c("prop_def_id")} = ?
        }, pd_id)
      end

    end

  end
end
