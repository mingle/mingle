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

# patching rails 2.1, the add index for schema_migrations table should be under table name prefix
module ActiveRecord
  module Calculations
    module ClassMethods
      def construct_calculation_sql(operation, column_name, options) #:nodoc:
        operation = operation.to_s.downcase
        options = options.symbolize_keys

        scope           = scope(:find)
        merged_includes = merge_includes(scope ? scope[:include] : [], options[:include])
        aggregate_alias = column_alias_for(operation, column_name)
        # this next line is the patched line
        column_name     = "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name column_name}" if column_names.include?(column_name.to_s)

        if operation == 'count'
          if merged_includes.any?
            options[:distinct] = true
            column_name = options[:select] || [connection.quote_table_name(table_name), primary_key] * '.'
          end

          if options[:distinct]
            use_workaround = !connection.supports_count_distinct?
          end
        end

        if options[:distinct] && column_name.to_s !~ /\s*DISTINCT\s+/i
          distinct = 'DISTINCT ' 
        end
        sql = "SELECT #{operation}(#{distinct}#{column_name}) AS #{aggregate_alias}"

        # A (slower) workaround if we're using a backend, like sqlite, that doesn't support COUNT DISTINCT.
        sql = "SELECT COUNT(*) AS #{aggregate_alias}" if use_workaround

        options[:group_fields].each_with_index { |group_field, i| sql << ", #{group_field} AS #{options[:group_aliases][i]}" } if options[:group]
        if options[:from]
          sql << " FROM #{options[:from]} "
        else
          sql << " FROM (SELECT #{distinct}#{column_name}" if use_workaround
          sql << " FROM #{connection.quote_table_name(table_name)} "
        end

        joins = ""
        add_joins!(joins, options[:joins], scope)

        if merged_includes.any?
          join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(self, merged_includes, joins)
          sql << join_dependency.join_associations.collect{|join| join.association_join }.join
        end

        sql << joins unless joins.blank?

        add_conditions!(sql, options[:conditions], scope)
        add_limited_ids_condition!(sql, options, join_dependency) if join_dependency && !using_limitable_reflections?(join_dependency.reflections) && ((scope && scope[:limit]) || options[:limit])

        if options[:group]
          group_key = connection.adapter_name == 'FrontBase' ?  :group_aliases : :group_fields
          sql << " GROUP BY #{options[group_key].join(",")} "
        end

        if options[:group] && options[:having]
          having = sanitize_sql_for_conditions(options[:having])

          # FrontBase requires identifiers in the HAVING clause and chokes on function calls
          if connection.adapter_name == 'FrontBase'
            having.downcase!
            having.gsub!(/#{operation}\s*\(\s*#{column_name}\s*\)/, aggregate_alias)
          end

          sql << " HAVING #{having} "
        end

        sql << " ORDER BY #{options[:order]} "       if options[:order]
        add_limit!(sql, options, scope)
        sql << ") #{aggregate_alias}_subquery" if use_workaround
        sql
      end
    end
  end
end

module ActiveRecord
  class Migrator
    class << self
      # Upgrade_Export was failing due to script/upgrade_export calls PluginMigrations#do_migration, whose #current_version needs to find schema_migrations_table_name
      # on the upgrading mi_xxx table set, but it is not shortened unfortunately.
      def schema_migrations_table_name
        ActiveRecord::Base.connection.safe_table_name 'schema_migrations'
      end
    end
  end
end

module ActiveRecord
  # patching rails 2.1, the add index for schema_migrations table should be under table name prefix
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      # Should not be called normally, but this operation is non-destructive.
      # The migrations module handles this automatically.
      def initialize_schema_migrations_table
        sm_table = ActiveRecord::Migrator.schema_migrations_table_name
        unless tables.detect { |t| quote_table_name(t) == quote_table_name(sm_table) }
          create_table(sm_table, :id => false) do |schema_migrations_table|
            schema_migrations_table.column :version, :string, :null => false
          end
          add_index sm_table, :version, :unique => true,
            :name => Base.table_name_prefix + 'unique_schema_migrations' + Base.table_name_suffix

          # Backwards-compatibility: if we find schema_info, assume we've
          # migrated up to that point:
          si_table = Base.table_name_prefix + 'schema_info' + Base.table_name_suffix

          if tables.detect { |t| t == si_table }

            old_version = select_value("SELECT version FROM #{quote_table_name(si_table)}").to_i
            assume_migrated_upto_version(old_version)
            drop_table(si_table)
          end
        end
      end
    end
  end
end

module ActiveRecord
  module Associations
    class HasManyThroughAssociation < HasManyAssociation #:nodoc:
      def find_target
        @reflection.klass.find(:all,
          :select     => construct_select,
          :conditions => construct_conditions,
          :from       => construct_from,
          :joins      => construct_joins,
          :order      => ActiveRecord::Base.connection.quote_order_by(@reflection.options[:order]),
          :limit      => @reflection.options[:limit],
          :group      => @reflection.options[:group],
          :readonly   => @reflection.options[:readonly],
          :include    => @reflection.options[:include] || @reflection.source_reflection.options[:include]
        )
      end
    end
  end
end

module ActiveRecord
  module Associations::ClassMethods
    # added scan number for oracle table name could have number,
    # and downcase for normal association comparation
    def tables_in_string(string)
      return [] if string.blank?
      string.scan(/([\.a-zA-Z_0-9]+).?\./).flatten.collect(&:downcase)
    end
    
    JoinDependency
    class JoinDependency
      JoinAssociation
      class JoinAssociation
        def association_join
          connection = reflection.active_record.connection
          join = case reflection.macro
            when :has_and_belongs_to_many
              " #{join_type} %s ON %s.%s = %s.%s " % [
                 table_alias_for(options[:join_table], aliased_join_table_name),
                 connection.quote_table_name(aliased_join_table_name),
                 options[:foreign_key] || reflection.active_record.to_s.foreign_key,
                 connection.quote_table_name(parent.aliased_table_name),
                 reflection.active_record.primary_key] +
              " #{join_type} %s ON %s.%s = %s.%s " % [
                 table_name_and_alias,
                 connection.quote_table_name(aliased_table_name),
                 klass.primary_key,
                 connection.quote_table_name(aliased_join_table_name),
                 options[:association_foreign_key] || klass.to_s.foreign_key
                 ]
            when :has_many, :has_one
              case
                when reflection.macro == :has_many && reflection.options[:through]
                  through_conditions = through_reflection.options[:conditions] ? "AND #{interpolate_sql(sanitize_sql(through_reflection.options[:conditions]))}" : ''

                  jt_foreign_key = jt_as_extra = jt_source_extra = jt_sti_extra = nil
                  first_key = second_key = as_extra = nil

                  if through_reflection.options[:as] # has_many :through against a polymorphic join
                    jt_foreign_key = through_reflection.options[:as].to_s + '_id'
                    jt_as_extra = " AND %s.%s = %s" % [
                      connection.quote_table_name(aliased_join_table_name),
                      connection.quote_column_name(through_reflection.options[:as].to_s + '_type'),
                      klass.quote_value(parent.active_record.base_class.name)
                    ]
                  else
                    jt_foreign_key = through_reflection.primary_key_name
                  end

                  case source_reflection.macro
                  when :has_many
                    if source_reflection.options[:as]
                      first_key   = "#{source_reflection.options[:as]}_id"
                      second_key  = options[:foreign_key] || primary_key
                      as_extra    = " AND %s.%s = %s" % [
                        connection.quote_table_name(aliased_table_name),
                        connection.quote_column_name("#{source_reflection.options[:as]}_type"),
                        klass.quote_value(source_reflection.active_record.base_class.name)
                      ]
                    else
                      first_key   = through_reflection.klass.base_class.to_s.foreign_key
                      second_key  = options[:foreign_key] || primary_key
                    end

                    unless through_reflection.klass.descends_from_active_record?
                      jt_sti_extra = " AND %s.%s = %s" % [
                        connection.quote_table_name(aliased_join_table_name),
                        connection.quote_column_name(through_reflection.active_record.inheritance_column),
                        through_reflection.klass.quote_value(through_reflection.klass.name.demodulize)]
                    end
                  when :belongs_to
                    first_key = primary_key
                    if reflection.options[:source_type]
                      second_key = source_reflection.association_foreign_key
                      jt_source_extra = " AND %s.%s = %s" % [
                        connection.quote_table_name(aliased_join_table_name),
                        connection.quote_column_name(reflection.source_reflection.options[:foreign_type]),
                        klass.quote_value(reflection.options[:source_type])
                      ]
                    else
                      second_key = source_reflection.primary_key_name
                    end
                  end

                  " #{join_type} %s ON (%s.%s = %s.%s%s%s%s) " % [
                    table_alias_for(through_reflection.klass.table_name, aliased_join_table_name),
                    connection.quote_table_name(parent.aliased_table_name),
                    connection.quote_column_name(parent.primary_key),
                    connection.quote_table_name(aliased_join_table_name),
                    connection.quote_column_name(jt_foreign_key),
                    jt_as_extra, jt_source_extra, jt_sti_extra
                  ] +
                  " #{join_type} %s ON (%s.%s = %s.%s%s) " % [
                    table_name_and_alias,
                    connection.quote_table_name(aliased_table_name),
                    connection.quote_column_name(first_key),
                    connection.quote_table_name(aliased_join_table_name),
                    connection.quote_column_name(second_key),
                    as_extra
                  ]

                when reflection.options[:as] && [:has_many, :has_one].include?(reflection.macro)
                  " #{join_type} %s ON %s.%s = %s.%s AND %s.%s = %s" % [
                    table_name_and_alias,
                    connection.quote_table_name(aliased_table_name),
                    "#{reflection.options[:as]}_id",
                    connection.quote_table_name(parent.aliased_table_name),
                    parent.primary_key,
                    connection.quote_table_name(aliased_table_name),
                    "#{reflection.options[:as]}_type",
                    klass.quote_value(parent.active_record.base_class.name)
                  ]
                else
                  foreign_key = options[:foreign_key] || reflection.active_record.name.foreign_key
                  " #{join_type} %s ON %s.%s = %s.%s " % [
                    table_name_and_alias,
                    connection.quote_table_name(aliased_table_name), # this line was added as the patch
                    connection.quote_column_name(foreign_key), # this line was added as the patch
                    connection.quote_table_name(parent.aliased_table_name), # this line was added as the patch
                    connection.quote_column_name(parent.primary_key) # this line was added as the patch
                  ]
              end
            when :belongs_to
              " #{join_type} %s ON %s.%s = %s.%s " % [
                 table_name_and_alias,
                 connection.quote_table_name(aliased_table_name),
                 reflection.klass.primary_key,
                 connection.quote_table_name(parent.aliased_table_name),
                 options[:foreign_key] || reflection.primary_key_name
                ]
            else
              ""
          end || ''
          join << %(AND %s.%s = %s ) % [
            connection.quote_table_name(aliased_table_name),
            connection.quote_column_name(klass.inheritance_column),
            klass.quote_value(klass.name.demodulize)] unless klass.descends_from_active_record?

          [through_reflection, reflection].each do |ref|
            join << "AND #{interpolate_sql(sanitize_sql(ref.options[:conditions]))} " if ref && ref.options[:conditions]
          end
          join              
        end

        protected
        
        def aliased_table_name_for(name, suffix = nil)
          if !parent.table_joins.blank? && parent.table_joins.to_s.downcase =~ %r{join(\s+\w+)?\s+#{active_record.connection.quote_table_name name.downcase}\son}
            @join_dependency.table_aliases[name] += 1
          end

          unless @join_dependency.table_aliases[name].zero?
            # if the table name has been used, then use an alias
            name = active_record.connection.table_alias_for "#{pluralize(reflection.name)}_#{parent_table_name}#{suffix}"
            # LINE ADDED #
            name = table_alias_for(name, nil)
            # LINE ADDED #
            
            table_index = @join_dependency.table_aliases[name]
            @join_dependency.table_aliases[name] += 1
            name = name[0..active_record.connection.table_alias_length-3] + "_#{table_index+1}" if table_index > 0
          else
            @join_dependency.table_aliases[name] += 1
          end

          name
        end
        
      end
    end
    
  end
end

if defined?(ActiveRecord::ConnectionAdapters::OracleAdapter)
  class ActiveRecord::ConnectionAdapters::OracleAdapter
    
    def write_lobs(table_name, klass, attributes)
      id = quote(attributes[klass.primary_key])
      klass.columns.select { |col| col.sql_type =~ /LOB$/i }.each do |col|
        value = attributes[col.name]
        value = value.to_yaml if col.text? && klass.serialized_attributes[col.name]
        next if value.nil?  || (value == '')
        # next line is the patched one: quote column name and also add "FOR UPDATE" because otherwise we get "ORA-22920: row containing the LOB value is not locked"
        lob = select_one("SELECT #{quote_column_name col.name} FROM #{quote_table_name(table_name)} WHERE #{klass.primary_key} = #{id} FOR UPDATE",
                         'Writable Large Object')[col.name]
        lob.write value
      end
    end
    
    def create_table(name, options = {}) #:nodoc:
      super(name, options)
      seq_name = options[:sequence_name] || "#{name}_seq"
      execute "CREATE SEQUENCE \"#{seq_name.upcase}\" START WITH 10000" unless options[:id] == false        # here is the patched line (quote sequence name)
    end
    
  end
end

if defined?(::JdbcSpec::Oracle)
  module ::JdbcSpec::Oracle
    def self.extended(mod)
      unless @lob_callback_added
        ActiveRecord::Base.class_eval do
          def after_save_with_oracle_lob
            self.class.columns.select { |c| c.sql_type =~ /LOB\(|LOB$/i }.each do |c|
              value = self[c.name]
              value = value.to_yaml if unserializable_attribute?(c.name, c)
              next if value.nil?  || (value == '')

              # patch: we quote column name on next line, otherwise transition_test breaks on reserved Oracle keyword 'comment'
              Rails.logger.debug { "write large object, type: #{c.type}, name: #{c.name}, table name: #{self.class.quoted_table_name}, value: #{value}"}
              connection.write_large_object(c.type == :binary, connection.quote_column_name(c.name), self.class.quoted_table_name, self.class.primary_key, quote_value(id), value)
            end
          end
        end

        ActiveRecord::Base.after_save :after_save_with_oracle_lob
        @lob_callback_added = true
      end
    end

    def create_table(name, options = {}) #:nodoc:
      super(name, options)
      seq_name = options[:sequence_name] || "#{name}_seq"
      raise ActiveRecord::StatementInvalid.new("name #{seq_name} too long") if seq_name.length > table_alias_length
      execute "CREATE SEQUENCE \"#{seq_name.upcase}\" START WITH 10000" unless options[:id] == false            # here is the patched line (quote sequence name)
    end
  end
end
