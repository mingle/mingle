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
  class BulkTag
    include SecureRandomHelper, CardsChanger, SqlHelper
    attr_reader :errors

    def initialize(project, card_id_criteria)
      @project = project
      @card_id_criteria = card_id_criteria
      @errors = []
      @bulk_update_tool = BulkUpdateTool.new(@project)
    end

    def remove_tag(tag_name)
      begin
        tag = @project.tags.find_by_name(tag_name)
        unless tag.nil?
          TemporaryIdStorage.with_session do |session_id|
            connection.insert_into(:table => TemporaryIdStorage.table_name,
                                   :insert_columns => ["session_id", "id_1"],
                                   :select_columns => ["'#{session_id}'", "taggable_id"],
                                   :select_distinct => true,
                                   :from => "#{Tagging.table_name}, #{Card.quoted_table_name}",
                                   :where => "taggable_type = 'Card' AND tag_id = #{tag.id} AND taggable_id #{@card_id_criteria.to_sql}",
                                   :generate_id => false)

            delete_tag_sql = "DELETE FROM #{Tagging.table_name} WHERE taggable_type = 'Card' AND tag_id = #{tag.id} AND taggable_id IN (SELECT id FROM #{Card.quoted_table_name} where id #{@card_id_criteria.to_sql})"
            connection.execute(delete_tag_sql)
            connection.bulk_update(:table => Card.table_name,
                                   :set => "updated_at = #{connection.datetime_insert_sql(Clock.now)}, modified_by_user_id = #{User.current.id}, version = version + 1",
                                   :for_ids => "IN (SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{session_id}')")

            @bulk_update_tool.card_versioning.create_card_versions_for_tag(session_id)
            update_index_for_tag(session_id)
          end
        end
        update_aggregates
        notify_cards_changing(@project)
        return true
      rescue Exception => e
        @errors << "Removal of tag #{tag_name} has failed unexpectedly.  Please try again."
        @project.logger.error(e.message)
        return false
      end
    end

    def tag_with(tags)
      TemporaryIdStorage.with_session do |cards_and_tags_added_session_id|
        Tag.parse(tags).each do |tag|
         begin
           tag = @project.tags.find_or_create(:name => tag) unless tag.respond_to?(:taggings)
           if tag.errors.empty?
            TemporaryIdStorage.with_session do |cards_already_with_tag_session_id|
              find_cards_that_have_tag_and_insert_into_temp_table(cards_already_with_tag_session_id, tag)
              cards_without_tag_criteria = "NOT EXISTS (SELECT tt.id_1 FROM #{TemporaryIdStorage.table_name} tt WHERE session_id = '#{cards_already_with_tag_session_id}' AND tt.id_1 = #{Card.quoted_table_name}.id)"
              cards_to_tag_criteria = " (#{Card.quoted_table_name}.id #{@card_id_criteria.to_sql}) AND #{cards_without_tag_criteria}"
              insert_cards_and_tags_added(tag, cards_to_tag_criteria, cards_and_tags_added_session_id)
              update_cards(cards_to_tag_criteria)
              insert_taggings(tag, cards_to_tag_criteria)
            end
          else
            tag.errors.each_full {|message| @errors.add_to_base message}
          end
        rescue Exception => e
          @errors << "Add tags has failed unexpectedly.  Please try again."
          @project.logger.error(e.message)
          return false
        end
      end

      @bulk_update_tool.card_versioning.create_card_versions_for_tag(cards_and_tags_added_session_id)
      update_index_for_tag(cards_and_tags_added_session_id)
      update_aggregates

      self.class.changed
      self.class.notify_observers(@project)
      true
    end
  end

  private

    def update_aggregates
      belongs_to_trees.each do |tree_configuration|
        tree_configuration.compute_aggregates_for_unique_ancestors(@card_id_criteria) do |aggregate_prop_def, ancestors|
          if aggregate_prop_def.aggregate_condition.present?
            aggregate_prop_def.compute_aggregates(ancestors)
          end
        end
      end
    end

    def belongs_to_trees
      find_tree_configurations_sql = "SELECT distinct tree_configuration_id FROM #{TreeBelonging.table_name} WHERE card_id #{@card_id_criteria.to_sql('card_id')}"
      connection.select_values(find_tree_configurations_sql).collect do |tree_id|
        @project.tree_configurations.find_by_id(tree_id)
      end
    end

    def insert_taggings(tag, cards_to_tag_criteria)
      connection.insert_into(:table => Tagging.table_name,
                             :insert_columns => ["tag_id", "taggable_type", "taggable_id"],
                             :select_columns => [tag.id, "'Card'", "#{Card.quoted_table_name}.id"],
                             :from => Card.quoted_table_name,
                             :where => cards_to_tag_criteria)
    end

    def update_cards(cards_to_tag_criteria)
      connection.bulk_update(:table => Card.table_name,
                             :set => "updated_at = #{connection.datetime_insert_sql(Clock.now)}, modified_by_user_id = #{User.current.id}, version = version + 1",
                             :for_ids => "IN (SELECT #{Card.quoted_table_name}.id FROM #{Card.quoted_table_name} WHERE #{cards_to_tag_criteria})")
    end

    def insert_cards_and_tags_added(tag, cards_to_tag_criteria, session_id)
      connection.insert_into(:table => TemporaryIdStorage.table_name,
                             :insert_columns => ["session_id", "id_1", "id_2"],
                             :select_columns => ["'#{session_id}'", "#{Card.quoted_table_name}.id", tag.id],
                             :from => Card.quoted_table_name,
                             :where => cards_to_tag_criteria,
                             :group_by => "#{Card.quoted_table_name}.id",
                             :generate_id => false)
    end

    def find_cards_that_have_tag_and_insert_into_temp_table(session_id, tag)
      connection.insert_into(:table => TemporaryIdStorage.table_name,
                             :insert_columns => ["session_id", "id_1"],
                             :select_columns => ["'#{session_id}'", "t.taggable_id"],
                             :from => "#{Tagging.table_name} t, #{Card.quoted_table_name}",
                             :where => "t.tag_id = #{tag.id} AND t.taggable_type = 'Card' AND t.taggable_id #{@card_id_criteria.to_sql}",
                             :generate_id => false)
    end

    def update_index_for_tag(session_id)
      sql = "SELECT id_1 FROM #{TemporaryIdStorage.table_name} WHERE session_id = '#{session_id}' ORDER BY id_1 DESC"
      card_ids = select_values(sql)
      FullTextSearch.index_card_selection(@project, card_ids)
    end

  end
end
