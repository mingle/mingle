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
  class BulkVersioning
    include SqlHelper

    attr_reader :project

    def initialize(project)
      @updater_id = SecureRandomHelper.random_32_char_hex
      @project = project
    end

    def create_card_versions(card_id_conditions, field_setters)
      card_id_conditions = card_id_conditions.gsub(/[?]/, "#{Card.quoted_table_name}")
      card_versioner = CardVersions.new(card_id_conditions, @updater_id)

      begin
        property_definition_columns = project.property_definitions_with_hidden.collect(&:column_name) + ['card_type_name']

        insert_standard_columns = create_insert_standard_columns
        select_standard_columns = create_select_standard_columns
        comment_columns = ['comment', 'system_generated_comment']

        insert_values = quote_column_names(comment_columns) + insert_standard_columns + quote_column_names(property_definition_columns)

        select_comment_columns = comment_columns.collect do |column_name|
          field_setters.key?(column_name) ? field_setters[column_name] : 'NULL'
        end

        select_property_defs = property_definition_columns.collect do |column_name|
          field_setters.key?(column_name) ? field_setters[column_name] : quote_column_name(column_name)
        end

        select_values = select_comment_columns + select_standard_columns + select_property_defs
        card_versioner.insert_versions(insert_values, select_values)

        insert_card_version_tags
        insert_card_version_attachments
        insert_card_version_events
        generate_changes
      ensure
        card_versioner.cleanup
      end
    end

    def create_card_versions_for_tag(session_id)
      standard_columns = create_insert_standard_columns
      property_definition_columns = project.property_definitions_with_hidden.collect(&:column_name) + ['card_type_name']
      insert_card_version_columns = ['id', 'card_id', 'updater_id'] + standard_columns + property_definition_columns
      card_columns = [connection.next_sequence_value_sql('card_version_id_sequence'), "#{Card.quoted_table_name}.id", "'#{@updater_id}'"] + standard_columns + property_definition_columns

      subselect = %Q{
        SELECT #{card_columns.join(',')}
          FROM #{Card.quoted_table_name}
         WHERE EXISTS (SELECT 1 FROM #{TemporaryIdStorage.table_name} WHERE id_1 = #{Card.quoted_table_name}.id AND session_id = '#{session_id}')
      }

      create_card_versions_sql = "INSERT INTO #{Card.quoted_versioned_table_name} (#{insert_card_version_columns.join(',')}) #{subselect}"

      execute(create_card_versions_sql)
      insert_card_version_tags
      insert_card_version_attachments
      insert_card_version_events
      generate_changes
    end

    def create_deletion_versions(card_id_conditions)
      card_versioner = CardVersions.new(card_id_conditions, @updater_id)
      begin
        insert_standard_columns = create_insert_standard_columns - quote_column_names(['description'])
        select_standard_columns = create_select_standard_columns - ['description']
        insert_values = insert_standard_columns + quote_column_names(["card_type_name"])
        select_values = select_standard_columns + quote_column_names(["card_type_name"])
        card_versioner.insert_versions(insert_values, select_values)
        insert_card_version_events(CardDeletionEvent)
        generate_changes
      ensure
        card_versioner.cleanup
      end
    end

    private

    def create_select_standard_columns
      updated_at = connection.datetime_insert_sql(Clock.now)
      ['(version + 1)','project_id', quote_column_name('number'),'name','description','created_at', updated_at,'created_by_user_id',User.current.id]
    end

    def create_insert_standard_columns
      quote_column_names(
        ['version','project_id','number','name','description','created_at','updated_at','created_by_user_id','modified_by_user_id']
      )
    end

    def insert_card_version_tags
      insert_columns = ['tag_id', 'taggable_type', 'taggable_id']
      select_columns = ['t.tag_id', "'Card::Version'", 'v.id']

      if connection.prefetch_primary_key?(Tagging)
        select_columns.unshift(connection.next_id_sql(Tagging.table_name))
        insert_columns.unshift('id')
      end

      insert_card_version_tags_sql = "INSERT INTO #{Tagging.table_name} (#{insert_columns.join(', ')})
                                      SELECT #{select_columns.join(', ')}
                                      FROM #{Card.quoted_versioned_table_name} v, #{Tagging.table_name} t
                                      WHERE t.taggable_type = 'Card' AND t.taggable_id = v.card_id AND v.updater_id = '#{@updater_id}'"

      execute(insert_card_version_tags_sql)
    end

    def insert_card_version_attachments
      connection.insert_into(:table => Attaching.table_name,
                             :insert_columns => ["attachment_id", "attachable_type", "attachable_id"],
                             :select_columns => ["t.attachment_id", "'Card::Version'", "v.id"],
                             :from => "#{Card.quoted_versioned_table_name} v, #{Attaching.table_name} t",
                             :where => "t.attachable_type = 'Card' AND t.attachable_id = v.card_id AND v.updater_id = '#{@updater_id}'")

    end

    def insert_card_version_events(event_type=CardVersionEvent)
      Event.bulk_generate(Card::Version, event_type, project, @updater_id)
    end

    def generate_changes
      HistoryGeneration.generate_changes_for_card_selection(project, @updater_id)
    end

    class CardVersions
      include SqlHelper

      def initialize(card_id_conditions, updater_id)
        @card_id_conditions = card_id_conditions
        @updater_id = updater_id
      end

      def insert_versions(insert_values, select_values)
        insert_values = ['id', 'card_id', 'updater_id'] + insert_values
        select_values = [connection.next_sequence_value_sql('card_version_id_sequence'), 'id', "'#{@updater_id}'"] + select_values

        connection.insert_into(:table => Card.versioned_table_name,
                               :insert_columns => insert_values,
                               :select_columns => select_values,
                               :from => Card.quoted_table_name,
                               :where => @card_id_conditions,
                               :generate_id => false)
      end

      def cleanup
      end
    end
  end
end
