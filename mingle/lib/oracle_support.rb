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

module OracleSupport
  module ShortIdentifiers
    IDENTIFIER_LIMIT = 30
    SEQUENCE_POSTFIX_LENGTH = 4  # _seq
    
    def  self.extended(base)
      base.class_eval do
        def indexes_with_shorten_identifier(table, name = nil)
          indexes_without_shorten_identifier(shorten_table(table))
        end

        def default_sequence_name_with_shorten_identifier(table, column)
          default_sequence_name_without_shorten_identifier(shorten_table(table), column)
        end

        def change_column_default_with_shorten_identifier(table_name, column_name, default)
          change_column_default_without_shorten_identifier(shorten_table(table_name), shorten_column(column_name), default)
        end

        def change_column_with_shorten_identifier(table_name, column_name, type, options = {})
          change_column_without_shorten_identifier(shorten_table(table_name), shorten_column(column_name), type, options)
        end

        def index_name_with_shorten_identifier(table_name, options)
          shorten_table(index_name_without_shorten_identifier(table_name, options))
        end

        def add_index_with_shorten_identifier(table_name, column_name, options = {})
          options[:name] = shorten_table(options[:name]) if options[:name]
          column_names = Array(column_name).map { |name| shorten_column(name) }
          add_index_without_shorten_identifier(shorten_table(table_name), column_names, options)
        end

        def create_table_with_shorten_identifier(table_name, options = {}, &block)
          options[:sequence_name] = shorten_table(options[:sequence_name]) if options[:sequence_name]
          create_table_without_shorten_identifier(shorten_table(table_name), options, &block)
        end

        def add_column_with_shorten_identifier(table_name, column_name, type, options = {})
          add_column_without_shorten_identifier(shorten_table(table_name), shorten_column(column_name), type, options)
        end

        def rename_column_with_shorten_identifier(table_name, column_name, new_column_name)
          rename_column_without_shorten_identifier(shorten_table(table_name), shorten_column(column_name), shorten_column(new_column_name))
        end

        def remove_column_with_shorten_identifier(table_name, column_name)
          remove_column_without_shorten_identifier(shorten_table(table_name), shorten_column(column_name))
        end

        def drop_table_with_shorten_identifier(name, options = {})
          options[:sequence_name] = shorten_table(options[:sequence_name]) if options[:sequence_name]
          drop_table_without_shorten_identifier(shorten_table(name), options)
        end

        def quote_column_name_with_shorten_identifier(column_name)
          quote_column_name_without_shorten_identifier(shorten_column(column_name))
        end

        def rename_table_with_shorten_identifier(table_name, new_name)
          rename_table_without_shorten_identifier(shorten_table(table_name), shorten_table(new_name))
        end

        def quote_table_name_with_shorten_identifier(table_name)
          quote_table_name_without_shorten_identifier(shorten_table(table_name))
        end

        def columns_with_shorten_identifier(table_name, name = nil)
          columns_without_shorten_identifier(shorten_table(table_name), name)
        end

        def table_exists_with_shorten_identifier?(table_name)
          table_exists_without_shorten_identifier?(shorten_table(table_name))
        end
        
        [:index_name, :indexes, :add_index, :add_column, :create_table, :rename_column, :remove_column, 
         :drop_table, :quote_column_name, :quote_table_name, :rename_table, :change_column,
         :columns, :table_exists?, :change_column_default, :default_sequence_name].each do |method|
           alias_method_chain method, :shorten_identifier
        end
        
        
        private
        def shorten_table(name)
          return name if name.to_s.size <= IDENTIFIER_LIMIT - SEQUENCE_POSTFIX_LENGTH
          name = name.to_s
          name[0..9] + Digest::SHA1.hexdigest(name)[0..15]
        end

        def shorten_column(name)
          return name if name.to_s.size <= IDENTIFIER_LIMIT
          name = name.to_s
          name[0..13] + Digest::SHA1.hexdigest(name)[0..15]
        end
      end
    end
  end
  
  module CharLimit
    
    def  self.extended(base)
      base.class_eval do
        def add_column_with_force_char_limit(table_name, column_name, type, options = {})
          add_column_without_force_char_limit(table_name, column_name, type, CharLimit.char_ify_limit(type, options))
        end
        alias_method_chain :add_column, :force_char_limit

        def change_column_with_force_char_limit(table_name, column_name, type, options = {})
          change_column_without_force_char_limit(table_name, column_name, type, CharLimit.char_ify_limit(type, options))
        end
        alias_method_chain :change_column, :force_char_limit
      end
    end
    
    def char_ify_limit(type, options)
      if type.to_sym == :string && options[:limit] && options[:limit].numeric?
        options[:limit] = "#{options[:limit]} CHAR"
      end
      options
    end
    module_function :char_ify_limit
    
  end
  
  module ColumnKeyWordsEscaping
    def  self.extended(base)
      base.class_eval do
        # ORACLE_KEY_WORDS = ['file', 'number', 'comment', 'size']
        
        def quote_column_name_with_keyword_escaping(name)
          name = name.to_s.upcase if ['file', 'number', 'comment', 'size', 'user', 'date'].include?(name.to_s.downcase.split('.').last)
          quote_column_name_without_keyword_escaping(name)
        end

        alias_method_chain :quote_column_name, :keyword_escaping
      end
    end
  end

  module StatementStrip
    def self.extended(base)
      base.class_eval do
        def execute_with_strip_semicolon(sql, name=nil)
          sql = sql[0..-2] if sql.ends_with?(';')
          execute_without_strip_semicolon(sql, name)
        end

        alias_method_chain :execute, :strip_semicolon
      end
    end
  end

  module NullabilitySupport
    def  self.extended(base)
      base.class_eval do
        def change_column_with_nullability_support(table_name, column_name, type, options = {}) 
          change_column_without_nullability_support(table_name, column_name, type, options)
          if options[:null] == true
            change_column_sql = "ALTER TABLE #{table_name} MODIFY #{quote_column_name(column_name)} NULL"
            execute(change_column_sql)
          end
        end

        alias_method_chain :change_column, :nullability_support
      end
    end
  end

  module ClobSupport
    def  self.extended(base)
      base.class_eval do
        def change_column_with_clob_support(table_name, column_name, type, options = {}) 
          type == :text ?  change_to_clob_column(table_name, column_name, options): change_column_without_clob_support(table_name, column_name, type, options)
        end

        alias_method_chain :change_column, :clob_support
        
        private
        def change_to_clob_column(table_name, column_name, options = {})
          temp_column_name = "#{column_name}_temp"
          add_column(table_name, temp_column_name, :text, options)
          execute "UPDATE #{quote_table_name(table_name)} set #{quote_column_name(temp_column_name)} = #{quote_column_name(column_name)}"
          remove_column(table_name, column_name)
          rename_column(table_name, temp_column_name, column_name)
        end
      end
    end

  end
  
  module ExtraSequenceHandling
    def self.extended(base)
      base.class_eval do
        # for the case like in migration 124, where we add an id column to a table and oracle doesn't add the corresponding sequence
        def add_column_with_sequence_creation(table_name, column_name, type, options = {})
          create_sequence(default_sequence_name(table_name, 'id'), 1) if type == :primary_key
          add_column_without_sequence_creation(table_name, column_name, type, options)
        end
        
        alias_method_chain :add_column, :sequence_creation
      end
    end
  end

  def self.extended(base)
    base.extend(ShortIdentifiers, ColumnKeyWordsEscaping, ClobSupport, StatementStrip, ExtraSequenceHandling, NullabilitySupport, CharLimit)
  end
  
  def self.included(base)
    self.extended(base)
  end
end

ActiveRecord
module ActiveRecord
  Base
  class Base
    class << self # Class methods
      alias_method :find_every_without_quote_order, :find_every

      def find_every(options)
        quote_order_by_column!(options)
        find_every_without_quote_order(options)
      end

      alias_method :find_from_ids_without_quote_order, :find_from_ids

      def find_from_ids(ids, options)
        quote_order_by_column!(options)
        find_from_ids_without_quote_order(ids, options)
      end
      
      ORACLE_BATCH_LIMIT = 1000
      
      def batched_find(ids)
        found = []
        ids.each_slice(ORACLE_BATCH_LIMIT) { |u| found = found + find(u) }                
        found
      end

      private
      # we added this nasty method
      def quote_order_by_column!(options)
        return if options[:order] =~ /lower\(.*\)/i || options[:order].nil?
        order_bys = options[:order].to_s.split(',')
        order_bys.collect! { |order_by| ActiveRecord::Base.connection.quote_order_by(order_by.trim) }
        options[:order] = order_bys.join(', ')
      end
    end
  end

  module AssociationPreload
    MAX_ENTRIES_IN_IN_CLAUSE = 1000

    # has_many patch for both Rails 2.3 and 3.0
    module HasManyAssociationPreloadSupport
      private

      # Split preload query into multiple queries each with max of 1000 entries in IN clause to avoid ORA-01795: maximum number of expressions in a list is 1000
      def find_associated_records(ids, reflection, preload_options)
        associated_records = []
        ids.each_slice(MAX_ENTRIES_IN_IN_CLAUSE) do |ids_chunk|
          associated_records += super(ids_chunk, reflection, preload_options)
        end
        associated_records
      end

    end

    ActiveRecord::Base.class_eval do
      extend ActiveRecord::AssociationPreload::HasManyAssociationPreloadSupport
    end

    ClassMethods.module_eval do
      def preload_belongs_to_association(records, reflection, preload_options={})
        return if records.first.send("loaded_#{reflection.name}?")
        options = reflection.options
        primary_key_name = reflection.primary_key_name

        if options[:polymorphic]
          polymorph_type = options[:foreign_type]
          klasses_and_ids = {}

          # Construct a mapping from klass to a list of ids to load and a mapping of those ids back to their parent_records
          records.each do |record|
            if klass = record.send(polymorph_type)
              klass_id = record.send(primary_key_name)
              if klass_id
                id_map = klasses_and_ids[klass] ||= {}
                id_list_for_klass_id = (id_map[klass_id.to_s] ||= [])
                id_list_for_klass_id << record
              end
            end
          end
          klasses_and_ids = klasses_and_ids.to_a
        else
          id_map = {}
          records.each do |record|
            key = record.send(primary_key_name)
            if key
              mapped_records = (id_map[key.to_s] ||= [])
              mapped_records << record
            end
          end
          klasses_and_ids = [[reflection.klass.name, id_map]]
        end

        klasses_and_ids.each do |klass_and_id|
          klass_name, id_map = *klass_and_id
          next if id_map.empty?
          klass = klass_name.constantize

          table_name = klass.quoted_table_name
          primary_key = reflection.options[:primary_key] || klass.primary_key
          column_type = klass.columns.detect{|c| c.name == primary_key}.type
          ids = id_map.keys.map do |id|
            if column_type == :integer
              id.to_i
            elsif column_type == :float
              id.to_f
            else
              id
            end
          end
          conditions = "#{table_name}.#{connection.quote_column_name(primary_key)} #{in_or_equals_for_ids(ids)}"
          conditions << append_conditions(reflection, preload_options)

          associated_records = []
          # Make several queries with no more than 1000 entries in each one, combining the results into a single array
          ids.each_slice(MAX_ENTRIES_IN_IN_CLAUSE) do |safe_for_oracle_ids|
            associated_records += klass.with_exclusive_scope do
              klass.find(:all, :conditions => [conditions, safe_for_oracle_ids],
                         :include => options[:include],
                         :select => options[:select],
                         :joins => options[:joins],
                         :order => options[:order])
            end
          end
          set_association_single_records(id_map, reflection.name, associated_records, primary_key)
        end
      end
    end
  end
end
