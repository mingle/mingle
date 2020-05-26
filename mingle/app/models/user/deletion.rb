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

class User
  module Deletion

    def self.included(base)
      base.extend(ClassMethods)
    end

    def deletable?
      self != User.current && !system? && !sole_admin? && !has_project_data? && !self.class.unorphaned_users_ids[self.id]
    end

    def before_destroy
      errors.add_to_base "Cannot delete undeletable user #{login}." unless deletable?
      deletable?
    end

    def has_project_data?
      return true if ProjectVariable.user_ids.include?(self.id)
      return true if Transition.used_user_ids.include?(self.id)
      return true if CardDefaults.any_using_user?(self)
      return true if UserFilterUsage.user_ids.include?(self.id)
      return true if HistorySubscription.user_ids.include?(self.id)
      false
    end

    module ClassMethods
      def unorphaned_users_ids
        ThreadLocalCache.get("user:unorphaned_users_ids") do
          has_ever_created_or_edited_project_data = has_ever_edited_any_traceable_data(all_traceable_project_model_tables, %w(created_by_user_id modified_by_user_id))

          has_ever_created_or_edited_dependencies = has_ever_edited_any_traceable_data([Dependency.table_name, Dependency::Version.table_name], %w(raising_user_id))

          has_ever_created_or_edited_objectives = has_ever_edited_any_traceable_data([Objective.table_name, Objective::Version.table_name], %w(modified_by_user_id))

          (has_ever_created_or_edited_project_data | has_ever_created_or_edited_dependencies | has_ever_murmured | has_ever_been_a_value_of_any_user_property_definition_or_modified_card |
              has_ever_created_or_edited_objectives).inject({}) do |user_ids_hash, user_id|
            user_ids_hash[user_id.to_i] = true
            user_ids_hash
          end
        end
      end

      def delete_orphan_users
        (deletable_users - admins).each(&:destroy)
      end

      def deletable_users
        User.all(:include => [:login_access]).select(&:deletable?)
      end

      private

      def has_ever_edited_any_traceable_data(all_traceable_model_tables, column_names)
        connection = ActiveRecord::Base.connection
        quoted_column_names = column_names.map {|column_name| connection.quote_column_name(column_name)}.join(', ')
        results = []
        all_traceable_model_tables.in_groups_of(50) do |group|
          sql = group.compact.collect {|table| "SELECT DISTINCT #{quoted_column_names} FROM #{connection.quote_table_name(table)}"}.join("\nUNION ALL\n")
          results |= connection.select_all(sql).collect {|user_ids_hash| user_ids_hash.values.compact}.flatten
        end
        results
      end

      def has_ever_been_a_value_of_any_user_property_definition_or_modified_card
        users_having_history = []
        Project.with_each_active_project do |project|
          user_in_history_columns = user_in_history_columns_for(project)
          next if user_in_history_columns.blank?
          users_having_history |= ActiveRecord::Base.connection.select_all(%{
            SELECT DISTINCT #{user_in_history_columns} FROM #{Card::Version.quoted_table_name}
          }).collect { |user_ids_hash| user_ids_hash.values.compact }.flatten
        end
        users_having_history
      end

      def has_ever_murmured
        ActiveRecord::Base.connection.select_values(%{
          SELECT DISTINCT author_id
          FROM #{Murmur.table_name}
        })
      end

      def user_in_history_columns_for(project)
        (ActiveRecord::Base.connection.select_values(%{
          SELECT column_name
          FROM property_definitions
          WHERE project_id = #{project.id}
          AND type='UserPropertyDefinition'
        }) + %w(created_by_user_id modified_by_user_id)).join(', ')
      end

      def all_traceable_project_model_tables
        traceables = [Page.table_name, Page::Version.table_name]
        Project.with_each_active_project do |project|
          traceables += [Card.table_name]
        end
        traceables
      end
    end
  end
end
