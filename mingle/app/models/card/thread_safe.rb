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

class Card
  module ThreadSafe
    module ActsAsVersionedFix
      def self.included(base)
        class << base
          def versioned_table_name
            Card::Version.table_name
          end

          def versioned_columns
            # versioned_columns got clean up when Card.reset_column_information called
            Project.current.columns_information(self).versioned_columns
          end

          def quoted_versioned_table_name
            ActiveRecord::Base.connection.quote_table_name(self.versioned_table_name)
          end
        end
      end
    end

    module CardTableName
      def table_name=(n)
        #ignore
      end
      def set_table_name(n)
        #ignore
      end
      def table_name
        if Project.activated?
          Project.current.full_card_table_name
        else
          origin_table_name
        end
      end

      def origin_table_name
        "cards"
      end
    end

    module CardVersionTableName
      def self.extended(b)
        # need to define in this way to overwrite table_name defined by acts as versioned plugin
        b.class_eval do
          def self.table_name=(n)
            #ignore
          end

          def self.set_table_name(n)
            #ignore
          end

          def self.table_name
            if Project.activated?
              Project.current.full_card_version_table_name
            else
              origin_table_name
            end
          end

          def self.origin_table_name
            "card_versions"
          end
        end
      end
    end

    class ColumnsInformation
      def initialize(columns)
        @columns = columns
      end

      def columns
        @columns
      end

      def columns_hash
        columns.inject({}) { |hash, column| hash[column.name] = column; hash }
      end
      memoize :columns_hash

      def column_names
        columns.map { |column| column.name }
      end
      memoize :column_names

      def content_columns
        columns.reject { |c| c.primary || c.name =~ /(_id|_count)$/} # ignore inheritance_column for cards/card_versions tables have no inheritance_column || c.name == inheritance_column }
      end
      memoize :content_columns

      def column_methods_hash #:nodoc:
        column_names.inject(Hash.new(false)) do |methods, attr|
          attr_name = attr.to_s
          methods[attr.to_sym]       = attr_name
          methods["#{attr}=".to_sym] = attr_name
          methods["#{attr}?".to_sym] = attr_name
          methods["#{attr}_before_type_cast".to_sym] = attr_name
          methods
        end
      end
      memoize :column_methods_hash

      def versioned_columns
        columns.select { |c| !Card.non_versioned_columns.include?(c.name) }
      end
      memoize :versioned_columns
    end

    module Columns
      def self.extended(base)
        ['columns', 'column_names', 'content_columns'].each do |m|
          base.class_eval <<-EOS, __FILE__, __LINE__ + 1
            def self.#{m}
              Project.current.columns_information(self).#{m}
            end
         EOS
        end

        ['columns_hash', 'column_methods_hash'].each do |m|
          base.class_eval <<-EOS, __FILE__, __LINE__ + 1
            def self.#{m}
              Project.current.columns_information(self).#{m} rescue {}
            end
          EOS
        end
      end

      def reset_column_information
        Project.current.clear_cached_results_for(:columns_information)
        CacheKey.touch(:structure_key, Project.current) unless !Project.activated?
      end

      def generated_methods?
        true
      end
    end

    module ProjectExt
      def self.included(base)
        base.class_eval do
          alias_method_chain :reload, :clear_columns_information
        end
      end

      def reload_with_clear_columns_information(*args)
        clear_cached_results_for(:columns_information)
        reload_without_clear_columns_information(*args)
      end

      def columns_information(clazz)
        table_name = if clazz <=card_class
                       full_card_table_name
                     elsif clazz <= card_version_class
                       full_card_version_table_name
                     else
                       raise "unknown type #{clazz}"
                     end
        ColumnsInformation.new(load_columns(table_name))
      end
      memoize :columns_information

      def load_columns(table_name)
        Rails.logger.debug("Attempting to load column information from cache for #{table_name}")
        key = KeySegments::ColumnInformation.new(self).to_s(table_name)
        Cache.get(key) do
          Rails.logger.debug("Populating cache for column information for #{table_name}")
          load_columns_from_db(table_name).tap do |r|
            Rails.logger.debug("Cached column information for #{table_name}")
          end
        end.tap do |r|
          Rails.logger.debug("Loaded column information from cache for #{table_name}")
        end
      end

      def full_card_table_name
        self.cards_table
      end

      def full_card_version_table_name
        self.card_versions_table
      end

      def card_class
        Card
      end

      def card_version_class
        Card::Version
      end

      private

      def load_columns_from_db(table_name)
        columns = connection.columns(table_name, "#{table_name} Columns")
        columns.each do |column|
          column.primary = column.name == "id"

          # force Oracle to see this column for what it is
          if column.name == "project_card_rank"
            column.instance_variable_set("@type", :decimal)
            column.instance_variable_set("@precision", 38)
            column.instance_variable_set("@scale", 15)
          end
        end
        columns
      end

    end
  end
end
