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
  class RemoveOrphanedPropertyColumns < Base

    class << self

      def description
        %Q{
          Removes DB columns cards tables that are leftovers from deleted
          property definitions that encountered a DB error during remove_column().
          This situation has occasionally manifested as a result of table lock
          contention (ORA-00054).
        }
      end

      def info_hash
        project_ids = project_ids_with_orphans
        {
          'name' => name,
          'required' => !project_ids.empty?,
          'description' => description,
          'project_ids' => project_ids
        }
      end

      def project_ids_with_orphans
        project_ids = []
        start = Time.now
        each_project do |id, identifier, cards_table, card_versions_table|
          card_prop_orphans = fetch_orphaned_columns(cards_table, id)
          vers_prop_orphans = fetch_orphaned_columns(card_versions_table, id)

          project_ids << id unless card_prop_orphans.empty? && vers_prop_orphans.empty?
        end

        Rails.logger.info("RemoveOrphanedPropertyColumns required check took: #{Time.now - start} seconds")
        project_ids
      end

      def required?
        !project_ids_with_orphans.empty?
      end

      def apply(project_ids=[])
        each_project(project_ids) do |id, identifier, cards_table, card_versions_table|
          orphaned_card_cols = remove_orphans_from_table(cards_table, id, identifier)
          orphaned_vers_cols = remove_orphans_from_table(card_versions_table, id, identifier)

          if orphaned_vers_cols || orphaned_card_cols
            Project.find_by_identifier(identifier).with_active_project do |project|
              project.cache_key.touch_structure_key
              project.cache_key.touch_card_key
            end
          end
        end
      end

      private

      def fetch_orphaned_columns(table, project_id)
        if ActiveRecord::Base.connection.database_vendor == :oracle
         query = %Q{SELECT column_name
                    FROM all_tab_cols
                    WHERE table_name = '#{table.upcase}'
                    AND owner = '#{Multitenancy.schema_name}'
                    AND column_name LIKE 'CP_%'
                    AND column_name NOT IN (
                      select UPPER(#{c("column_name")}) from #{t("property_definitions")} where #{c("project_id")} = #{project_id}
                    )}
        else
          query = %Q{SELECT column_name
          FROM information_schema.columns
          WHERE table_name = '#{table}'
            AND column_name LIKE 'cp_%'
            AND column_name NOT IN (
                      select #{c("column_name")} from #{t("property_definitions")} where #{c("project_id")} = #{project_id}
                    )
            }
        end
          orphaned_cols = execute(query).map { |c| c["column_name"] }
      end

      def remove_orphans_from_table(table, project_id, project_identifier)
          orphaned_cols = fetch_orphaned_columns(table, project_id)
          return false if orphaned_cols.empty?
          orphaned_cols.each do |orphan|
            Rails.logger.warn "Removing orphaned column #{orphan} from table #{table} of project #{project_identifier}"
            ActiveRecord::Base.connection.remove_column(table, orphan)
            Rails.logger.warn "-- done"
          end
          return true
      end

    end

  end
end
