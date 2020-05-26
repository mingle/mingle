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

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'bulk_sql_helper'
require 'project_import_bulk_update_support'
require 'oracle_support'

class ActiveRecord::ConnectionAdapters::AbstractAdapter
  def supports_constraints?
    true
  end

  def with_disabled_contraints
    yield
  end

  def explain(sql, raise_error=false)
    return if sql.strip !~ /\Aselect/i
    __explain__(sql).map do |row|
      row.values.last
    end.join("\n")
  rescue => e
    raise if raise_error
    Rails.logger.error("Explain sql #{sql} failed: #{e.message}\n#{e.backtrace.join("\n")}")
  end

  alias :origin_log_info :log_info
  def log_info(sql, name, ms)
    if MingleConfiguration.explain_sql?(ms) && sql.strip =~ /\Aselect/i
      name = '%s (%.1fms)' % [name || 'SQL', ms]
      Rails.logger.info("AUTO SQL EXPLAIN #{name}: #{sql}\n#{explain(sql) || "Could not explain"}")
      Rails.logger.info("----> caller:\n#{caller.join("\n")}")
    else
      origin_log_info(sql, name, ms)
    end
  end

  def remove_index!(table_name, index_name) #:nodoc:
    execute "DROP INDEX #{index_name}"
  end

  def create_table_if_does_not_exist(table_name, &proc)
    create_table(table_name, &proc) unless table_exists?(table_name)
  end

  def date_plus_days(date, days)
    "#{date} + #{days}"
  end

  def date_minus_days(date, days)
    "#{date} - #{days}"
  end

  def date_minus_date(date, another_date)
    "#{date} - #{another_date}"
  end

  def drop_temporary_table(name)
    drop_table(name)
  end

  def drop_temporary_table_if_exists(name)
    execute("DROP TABLE #{quote_table_name name}") rescue nil
  end

  def drop_table_if_exists(name)
    drop_table(name) if table_exists?(name)
  end

  def column_exists?(table_name, column)
    columns(table_name).any?{|c| c.name.to_s.downcase == column.to_s.downcase}
  end

  def drop_not_null_constraint(table_name, column_name, options={})
    table_name = ActiveRecord::Base.table_name_prefix + table_name.to_s
    original_type = columns(table_name).detect{|col| col.name.to_s.downcase == column_name.to_s.downcase }.type
    change_column(table_name, column_name, original_type, options.merge(:null => true))
  end

  def create_not_null_constraint(table_name, column_name, options={})
    table_name = ActiveRecord::Base.table_name_prefix + table_name.to_s
    original_type = columns(table_name).detect{|col| col.name.to_s.downcase == column_name.to_s.downcase }.type
    change_column(table_name, column_name, original_type, options.merge(:null => false))
  end

  def case_sensitive_inequality(value_one, value_two)
    "#{value_one} != #{value_two}"
  end

  def case_insensitive_inequality(value_one, value_two)
    "LOWER(#{value_one}) != LOWER(#{value_two})"
  end

  def lower(value)
    return "NULL" if value.blank?
    "LOWER(#{value})"
  end

  def string_limit
    65535
  end

  def safe_table_name(proposed_name)
    "#{ActiveRecord::Base.table_name_prefix}#{proposed_name}"
  end

  def max_precision
    38
  end

  def column_defined_in_model?(model, column_name)
    model.column_names.any? {|n| n == column_name}
  end

  def create_sequence(name, start)
    raise 'not supported'
  end

  def drop_sequence(name)
    raise 'not supported'
  end

  def sequence_exists?(name)
    raise 'not supported'
  end

  def database_vendor
    raise 'current database is not supported'
  end

  def next_sequence_value_sql(sequence_name)
    raise 'not supported'
  end

  def next_id_sql(table_name)
    next_sequence_value_sql(default_sequence_name(table_name, nil))
  end

  def cast_as_integer(castable)
    castable = "NULL" if castable.blank?
    "CAST(CAST(#{castable} AS NUMERIC) AS INTEGER)"
  end

  def supports_sequences?
    false
  end

  def set_sequence_value(sequence_name, value)
    raise 'not supported'
  end

  def current_sequence_value(sequence_name)
    raise 'not supported'
  end

  def quote_order_by(order_by)
    return order_by if order_by.blank?
    order_by.split(',').collect do |order_by_column|
      full_column_name, order_direction = order_by_column.strip.split(' ')
      result = quote_full_column_name(full_column_name)
      result << " " << order_direction  if order_direction
      result
    end.join(", ")
  end

  def not_null_or_empty(column)
    "#{column} != ''"
  end

  def datetime_insert_sql(value)
    if value.blank?
      "NULL"
    elsif value.acts_like?(:time) && value.respond_to?(:usec)
      "'#{value.to_formatted_s(:db)}.#{sprintf("%06d", value.usec)}'"
    else
      "'#{value}'"
    end
  end

  def date_insert_sql(value)
    return "NULL" if value.blank?
    "date '#{value}'"
  end

  def select_date_sql(column_name)
    "CAST(#{column_name} AS DATE)"
  end

  def alias_if_necessary_as(alias_name)
    "as #{alias_name}"
  end

  def as_char(value, size)
    value = "NULL" if value.blank?
    "CAST(#{value} AS CHAR(#{size}))"
  end

  def as_boolean(value)
    "CAST(#{value} AS BOOLEAN)"
  end

  def as_date(value)
    "TO_DATE(TO_CHAR(#{value}, 'YYYY-MM-DD'), 'YYYY-MM-DD')"
  end

  def as_number(value, scale=nil)
    value = "NULL" if value.blank?
    scale = Project.current.precision if scale.nil? && Project.activated?
    "CAST(#{value} AS DECIMAL(#{max_precision}, #{scale || 0}))"
  end

  # if column is a numeric type, assuming precision and scale are handled
  # by column definition. Generally, when precision and scale are not specified in
  # the column definition, database-specific limits are implied.
  def as_high_precision_number(value)
    value = "NULL" if value.blank?
    "CAST(#{value} AS #{high_precision_number_type})"
  end

  def as_padded_number(value, precision)
    as_number(value, precision)
  end

  def quote_value(value)
    return "NULL" if value.blank?
    %{#{quote_character}#{value}#{quote_character}}
  end

  def quote_character
    '"'
  end

  def column_name(column_name)
    column_name
  end

  def true_value
    1
  end

  def false_value
    0
  end

  def from_no_table
    ""
  end

  def order_by(column_name, order)
    "#{column_name} #{order}"
  end

  def db_specific_table_name(table_name)
    table_name
  end

  def quote_identifier(identifier)
    quote_value(identifier)
  end

  # used for column and join aliases, which need to be shortened to < 30 characters in Oracle
  def identifier(identifier)
    identifier
  end

  def limit(limit)
    limit
  end

  def verify_charset!

  end

  def cards_table_options
    {}
  end

  def quote_column_names(column_names)
    column_names.collect { |column_name| quote_column_name(column_name) }
  end

  private

  def quote_full_column_name(full_column_name)
    column_name, table_name = full_column_name.split('.').reverse
    if table_name
      "#{quote_table_name(table_name)}.#{quote_column_name(column_name)}"
    else
      "#{quote_column_name(column_name)}"
    end
  end

end

module SmartQuoting
  def self.included(base)
    self.extended(base)
  end
  def self.extended(base)
    base.class_eval do
      def quote_column_name_with_distinguish_table_name(full_name)
        tokens = full_name.to_s.split('.')
        return quote_column_name_without_distinguish_table_name(full_name) if tokens.size < 2
        table_name, column_name = tokens
        [table_name, quote_column_name_without_distinguish_table_name(column_name)].join(".")
      end

      def quote_column_name_with_avoid_double_quoting(name)
        return name if name.to_s.starts_with?(ActiveRecord::Base.connection.quote_character) && name.to_s.ends_with?(ActiveRecord::Base.connection.quote_character)
        quote_column_name_without_avoid_double_quoting(name)
      end

      def quote_table_name_with_avoid_double_quoting(name)
        return name if name.to_s.starts_with?(ActiveRecord::Base.connection.quote_character) && name.to_s.ends_with?(ActiveRecord::Base.connection.quote_character)
        quote_table_name_without_avoid_double_quoting(name)
      end

      alias_method_chain :quote_table_name, :avoid_double_quoting
      alias_method_chain :quote_column_name, :avoid_double_quoting
      alias_method_chain :quote_column_name, :distinguish_table_name
    end
  end
end

module AppendStringFix
  module PostgreSQL
    def append_to(column_name)
      "#{quote_column_name(column_name)} || (?)"
    end
  end
end

module PostgresLowerFunctionFix
  def case_insensitive_inequality(value_one, value_two)
     "LOWER(CAST(#{value_one} AS TEXT)) != LOWER(CAST(#{value_two} AS TEXT))"
   end
end

module OracleAdapterExtension
  include SQLBulkMethods
  include ProjectImportOracleBulkUpdate

  def database_vendor
    :oracle
  end

  def switch_schema(schema_name)
    execute("ALTER SESSION SET CURRENT_SCHEMA = #{schema_name}")
  end

  def schema_exists?(schema_name)
    select_value SqlHelper.sanitize_sql("SELECT USERNAME FROM ALL_USERS WHERE USERNAME = ?", schema_name.upcase)
  end

  def schemata_with_prefix(prefix)
    select_values SqlHelper.sanitize_sql("SELECT USERNAME FROM ALL_USERS WHERE USERNAME LIKE ? ESCAPE '\\'", "#{prefix.upcase}%")
  end

  def create_tenant_schema(schema_name)
    password = "p#{SecureRandomHelper.random_32_char_hex[0..15]}"
    execute("CREATE USER #{schema_name} IDENTIFIED BY #{password} DEFAULT TABLESPACE users QUOTA UNLIMITED ON users TEMPORARY TABLESPACE temp")
  end

  def drop_tenant_schema(schema_name)
    execute("DROP USER #{schema_name} CASCADE")
    result = execute("SELECT COUNT(*) AS TABLESPACE_COUNT FROM DBA_TABLESPACES WHERE TABLESPACE_NAME='#{schema_name}'")
    execute("DROP TABLESPACE #{schema_name} INCLUDING CONTENTS AND DATAFILES") if result[0]['tablespace_count'].to_i > 0
  end

  def redistribute_project_card_rank(cards_table, min, interval)
    sql = %Q{
       MERGE INTO #{cards_table} c
            USING (SELECT id, row_number() OVER (ORDER BY project_card_rank) AS position FROM #{cards_table}) sorted
               ON (c.id = sorted.id)
WHEN MATCHED THEN
       UPDATE SET c.project_card_rank = (CAST(? AS #{high_precision_number_type}) + (sorted.position * CAST(? AS #{high_precision_number_type})))
     }

     execute SqlHelper.sanitize_sql(sql, min, interval)
  end

  # even though DECIMAL is implemented as NUMBER in Oracle, DECIMAL
  # without specified precision and scale is NUMBER(38,0) -- i.e. "integer";
  # compare this to NUMBER without precision and scale where the value is
  # stored "as-is", with precision and scale limited to the DB implementation
  def high_precision_number_type
    "NUMBER"
  end

  def string_limit
    4000
  end

  def __explain__(sql)
    execute("EXPLAIN PLAN FOR #{sql}", "EXPLAIN SQL")
    select_all("SELECT plan_table_output FROM TABLE(dbms_xplan.display('plan_table',null,'all'))", "EXPLAIN SQL")
  end

  def safe_table_name(proposed_name)
    shorten_table("#{ActiveRecord::Base.table_name_prefix}#{proposed_name}")
  end

  def column_name(column_name)
    shorten_column(column_name)
  end

  def insert_large_objects(table, record, new_id, columns=table.columns)
    columns.select { |c| c.sql_type =~ /LOB\(|LOB$/i }.each do |c|
      value = record[c.name]
      next if value.blank?
      write_large_object(c.type == :binary, quote_column_name(c.name), quote_table_name(table.target_name), 'id', new_id.to_s, value)
    end
  end

  def max_precision
    38
  end

  def column_defined_in_model?(model, column_name)
    super(model, shorten_column(column_name))
  end

  def create_sequence(name, start, options={})
    if options[:strict_counter]
      execute "CREATE SEQUENCE #{name} START WITH #{start} INCREMENT BY 1 MAXVALUE 999999999999999999999 CYCLE ORDER NOCACHE"
    else
      execute "CREATE SEQUENCE #{name} START WITH #{start}"
    end
  end

  def drop_sequence(name)
    execute "DROP SEQUENCE #{name}"
  end

  def sequence_exists?(name)
    res = execute "SELECT COUNT(*) FROM all_sequences WHERE sequence_name = '#{name.to_s.upcase}'"
    res[0].values[0].to_i != 0
  end

  def next_sequence_value_sql(seq_name)
    "#{seq_name}.nextval"
  end

  def supports_sequences?
    true
  end

  def set_sequence_value(sequence_name, value)
    drop_sequence(sequence_name)
    create_sequence(sequence_name, value)
  end

  def last_generated_value(sequence_name)
    select_value(last_generated_value_sql(sequence_name)).to_i
  end

  def last_generated_value_sql(sequence_name)
    "SELECT LAST_NUMBER FROM ALL_SEQUENCES WHERE LOWER(SEQUENCE_NAME)=LOWER('#{sequence_name}') AND LOWER(SEQUENCE_OWNER)=LOWER('#{Multitenancy.schema_name}')"
  end

  def current_sequence_value(sequence_name)
    select_value("select #{sequence_name}.CURRVAL from dual").to_i
  end

  # Resets sequence to the max value of the table's pk if present.
  def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
    unless pk and sequence
      default_pk, default_sequence = *pk_and_sequence_for(shorten_table(table))
      pk ||= default_pk
      sequence ||= (default_sequence || default_sequence_name(table, pk))
    end
    if pk
      if sequence
        mpk = select_value("SELECT MAX(#{quote_column_name(pk)}) FROM #{quote_table_name(table)}")
        set_sequence_value(sequence, mpk.to_i + 1) if mpk.to_i != 0
      else
        @logger.warn "#{table} has primary key #{pk} with no default sequence" if @logger
      end
    end
  end

  def not_null_or_empty(column)
    "#{column} IS NOT NULL"
  end

  def datetime_insert_sql(value)
    if value.blank?
      "NULL"
    elsif value.acts_like?(:time) && value.respond_to?(:usec)
      "TO_TIMESTAMP('#{value.to_formatted_s(:db)}.#{sprintf("%06d", value.usec)}', 'YYYY-MM-DD HH24:MI:SS.FF')"
    else
      "TO_DATE('#{value}', 'YYYY-MM-DD HH24:MI:SS')"
    end
  end

  def date_insert_sql(value)
    sql_value = value.blank? ? "NULL" : "'#{value}'"
    "TO_DATE(#{sql_value}, 'YYYY-MM-DD')"
  end

  def select_date_sql(column_name)
    "TO_CHAR(#{column_name}, 'YYYY-MM-DD')"
  end

  def alias_if_necessary_as(alias_name)
    ""
  end

  def as_char(value, size)
    value = "NULL" if value.blank?
    "CAST(#{value} AS VARCHAR2(#{size}))"
  end

  def as_boolean(value)
    "CAST(#{value} AS NUMBER(1,0))"
  end

  def as_padded_number(value, precision)
    value = "NULL" if value.blank?
    decimal = precision == 0 ? '' : ".#{'0'*precision}"
    format = "'FM#{'9'*(37-precision)}0#{decimal}'"
    "TO_CHAR(#{value}, #{format})"
  end

  def bulk_insert(model, data)
    cnames = model.column_names.map(&:downcase)
    cnames.delete('id')
    quoted_cnames = cnames.map {|cname| quote_column_name(cname)}
    id_sql = ActiveRecord::Base.connection.next_id_sql(model.table_name)
    values = data.map do |row|
      cnames.map { |column_name| [column_name, row[column_name]] }
    end

    first_insert = select_from_dual(values[0].map {|cname, value| "? as #{quote_column_name(cname)}"}.join(", "))
    rest = values[1..-1].map do |row|
      select_from_dual(row.map{|_,value| '?'}.join(", "))
    end

    sql = %{
      INSERT INTO #{quote_table_name(model.table_name)}
             SELECT #{id_sql}, #{quoted_cnames.join(", ")}
             FROM (#{[first_insert, rest].flatten.join(" UNION ALL ")})
    }

    values_without_cname = values.map{|row| row.map{|_,value| value}}
    execute(SqlHelper.sanitize_sql(sql, *(values_without_cname.flatten)))
  end

  def insert_multi_rows(table_name, columns, data)
    rows = data.map do |values|
      sql = SqlHelper.sanitize_sql("select #{(['?'] * values.size).join(",\n")} from dual", *values)
      # need to convert empty_clob() to '' to avoid ORA-01790 issue with union and data types
      sql.gsub("empty_clob()", "''")
    end

    sql = %Q{
        INSERT INTO #{quote_table_name(table_name)}
          (#{quote_column_names(columns).join(",\n")})
          #{rows.join("\nUNION ALL ")}
      }
    execute(sql)
  end

  def select_from_dual(content)
    "select #{content} from dual"
  end

  # we need the insert method to return an id (project import needs this), and this patch does that.  it's based on the postgresql patch.
  def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
    if insert_id = super
      insert_id
    else
      # Extract the table from the insert sql. Yuck.
      table = sql.split(" ", 4)[2].gsub('"', '')

      # If neither pk nor sequence name is given, look them up.
      unless pk || sequence_name
        pk, sequence_name = *pk_and_sequence_for(table)
      end

      # If a pk is given, fallback to default sequence name.
      # Don't fetch last insert id for a table without a pk.
      if pk && sequence_name ||= default_sequence_name(table, pk)
        Integer(select_value("SELECT #{sequence_name}.currval from dual"))
      end
    end
  end

  def concat(*column_names)
    column_names.join(' || ')
  end

  def value_out_of_precision(column_name, precision)
    "REGEXP_LIKE(#{quote_column_name(column_name)}, '^.*[.][0-9]{#{precision + 1},}$')"
  end

  def from_no_table
    "FROM dual"
  end

  def quote_table_name(table_name)
    %{"#{table_name.upcase}"}
  end

  def db_specific_table_name(table_name)
    table_name.gsub(/_*(.*)/) { $1 }     # strip leading underscores
  end

  # used for column and join aliases, which need to be shortened to < 30 characters in Oracle
  def identifier(identifier)
    shorten_column(identifier)
  end

  def limit(limit)
    "#{limit} CHAR"
  end

  def is_number(column_name)
    "REGEXP_LIKE(TRIM(#{column_name}), '^-?(([0-9]+([.][0-9]*)?)|([0-9]*[.][0-9]+))$')"
  end

  def verify_charset!
    server_charset = select_value <<-SQL
      SELECT value
        FROM nls_database_parameters
       WHERE parameter = 'NLS_CHARACTERSET'
      SQL
    raise "Oracle server character set must be set to 'AL32UTF8'" unless server_charset == 'AL32UTF8'
  end

  def add_limit_offset!(sql, options = {})
    super || sql
  end
end

module OracleGeneralPatches
  module ::ActiveRecord
    module ConnectionAdapters #:nodoc:
      class Column
        private
        #if a column is of type number with no
        def extract_scale(sql_type)
          case sql_type
            when /^(numeric|decimal|number)\((\d+)\)/i then 0
            when /^(numeric|decimal|number)\((\d+)(,(\d+))\)/i then $4.to_i
            when /^number\z/i then 0
          end
        end
      end
    end
  end
end

module OracleJDBCPatches
  if defined?(::JdbcSpec)
    module ::JdbcSpec::Oracle
      module Column
        def self.string_to_time(string, klass)
          return string unless string.is_a?(String)
          return nil if string.empty?

          fast_string_to_time(string) || fallback_string_to_time(string)
        end
      end

      def indexes(table, name = nil)
        sql = %Q{SELECT
                   all_ind_columns.column_name,
                   all_indexes.uniqueness,
                   all_ind_columns.index_name
                FROM all_ind_columns
                LEFT JOIN all_indexes
                  ON all_indexes.index_name = all_ind_columns.index_name
                     AND all_indexes.owner = all_ind_columns.INDEX_owner
                     AND all_indexes.TABLE_NAME = all_ind_columns.TABLE_NAME
                WHERE
                  all_ind_columns.table_name=?
                  AND all_ind_columns.index_owner=?
                  AND all_indexes.generated = 'N'}
        values = self.select_rows(SqlHelper.sanitize_sql(sql, table.upcase, Multitenancy.schema_name.upcase))
        values.group_by do |value|
          value[2]
        end.map do |index, values|
          ActiveRecord::ConnectionAdapters::IndexDefinition.new(table, index, values.first[1] == 'UNIQUE', values.map{|v| v[0]})
        end
      end

      def index_exists?(table_name, index_name, default)
        sql = "select index_name from all_indexes where index_name = ? and owner = ?"
        self.select_value(SqlHelper.sanitize_sql(sql, index_name.upcase, Multitenancy.schema_name.upcase))
      end

      # bring back rails remove_index
      def remove_index(table_name, options = {})
        index_name = index_name(table_name, options)
        unless index_exists?(table_name, index_name, true)
          Rails.logger.warn("Index name '#{index_name}' on table '#{table_name}' does not exist. Skipping.")
          return
        end
        remove_index!(table_name, index_name)
      end

      def table_exists?(name)
        sql = "select table_name from all_tables where table_name = ? and owner = ?"
        !!self.select_value(SqlHelper.sanitize_sql(sql, name.upcase, Multitenancy.schema_name.upcase))
      end

      def rename_table(name, new_name)
        execute "ALTER TABLE #{name} RENAME TO #{new_name}"
        start_with = select_value("select #{name}_seq.nextval from dual")
        execute "CREATE SEQUENCE #{new_name}_seq START WITH #{start_with}"
        execute "DROP SEQUENCE #{name}_seq"
      end

      def tables
        @connection.tables(nil, oracle_schema)
      end

      def oracle_schema
        Multitenancy.schema_name.upcase
      end

      def active?
        execute config[:connection_alive_sql]
        true
      rescue Exception => e
        false
      end
    end
  end

  def recreate_database(name)
    structure_drop.split(";\n\n").each do |ddl|
      execute(ddl)
    end
  end

  # adapted from MRI oracle adapter, to make jdbc adapter works in the same way
  def next_sequence_value(sequence_name)
    id = 0
    result = execute("select #{sequence_name}.nextval id from dual")
    result.each { |r| id = r['id'].to_i }
    id
  end

  def prefetch_primary_key?(table_name = nil)
    true
  end

  # adapted from the version in Oracle adapter
  # client need take care of shorten table name by themselves
  def pk_and_sequence_for(table_name)
    no_pk_tables = ["project_variables_property_definitions", 'card_types_property_definitions', 'schema_migrations'].map(&method(:safe_table_name))
    no_pk_tables.include?(table_name) ? nil : ['ID', nil]
  end

  def quote(value, column = nil) #:nodoc:
    return value.quoted_id if value.respond_to?(:quoted_id)
    # the next line is a patched line: we make a potentially bad assumption that a string bigger than 4000 is going to be inserted into a clob column -- this patch is
    # needed because SQL with a string literal greater than 4000 chars is illegal for Oracle. So instead we insert empty_clob(), and then an after_save hook in
    # the jdbc oracle adapter will insert the actual value.  (test with: test_commit_message_is_truncated_before_being_written_to_the_db in revision_test)
    return %Q{empty_clob()} if (value.is_a?(String) && value.size > 4000)

    # next line is a patched line -- make sure value isn't null in first conditional, otherwise it will insert "empty_clob()" in when we want it to be null.
    # there seems to be a bug for this: http://jira.codehaus.org/browse/JRUBY-2771
    if value && column && [:text, :binary].include?(column.type)
      if /(.*?)\([0-9]+\)/ =~ column.sql_type
        %Q{empty_#{ $1.downcase }()}
      else
        %Q{empty_#{ column.sql_type.downcase rescue 'blob' }()}
      end
    else
      if column && column.type == :primary_key
        return value.to_s
      end
      case value
      when String, ActiveSupport::Multibyte::Chars
        if column && column.type == :datetime
          %Q{TIMESTAMP'#{value}'}
        elsif column && [:integer, :float].include?(column.type)            # this elsif block is a patch; I took the code from quoting.rb
          value = column.type == :integer ? value.to_i : value.to_f
          value.to_s
        else
          %Q{'#{quote_string(value)}'}
        end
      when NilClass
          'null'
      when TrueClass
          '1'
      when FalseClass
          '0'
      when Numeric
          value.to_s
      when Date, Time
          %Q{TIMESTAMP'#{value.strftime("%Y-%m-%d %H:%M:%S")}'}
        else
          %Q{'#{quote_string(value.to_yaml)}'}
      end
    end
  end

  # a patch to make our string limit 255 characters long instead of the default 4000 bytes
  def native_database_types #:nodoc:
    @connection.native_database_types.merge({ :string      => { :name => "VARCHAR2", :limit => "255 CHAR" } })
  end

end

module PostgresAdapterExtension

  include SQLBulkMethods
  include AppendStringFix::PostgreSQL
  include PostgresLowerFunctionFix
  include ProjectImportPostgresBulkUpdate

  def database_vendor
    :postgresql
  end

  def switch_schema(schema_name)
    execute("SET SESSION search_path TO #{schema_name.downcase}")
  end

  def schema_exists?(schema_name)
    select_value("SELECT nspname FROM pg_namespace WHERE lower(nspname) = '#{schema_name.downcase}'")
  end

  def schemata_with_prefix(prefix)
    select_values SqlHelper.sanitize_sql("SELECT nspname FROM pg_namespace WHERE lower(nspname) LIKE ? ESCAPE '\\'", "#{prefix.downcase}%")
  end

  def create_tenant_schema(schema_name)
    execute("CREATE SCHEMA #{schema_name}")
  end

  def drop_tenant_schema(schema_name)
    execute("DROP SCHEMA #{schema_name} CASCADE")
  end

  def active?
    execute config[:connection_alive_sql]
    true
  rescue Exception => e
    false
  end

  # arbitrary precision when neither precision and scale are specified
  def high_precision_number_type
    "NUMERIC"
  end

  def redistribute_project_card_rank(cards_table, min, interval)
    sql = %Q{
      UPDATE #{cards_table}
         SET project_card_rank = (CAST(? AS #{high_precision_number_type}) + (sorted.position * CAST(? AS #{high_precision_number_type})))
        FROM (SELECT id, row_number() OVER (ORDER BY project_card_rank) AS position FROM #{cards_table}) sorted
       WHERE sorted.id = #{cards_table}.id;
    }
    execute SqlHelper.sanitize_sql(sql, min, interval)
  end

  # bring back rails remove_index
  def remove_index(table_name, options = {})
    index_name = index_name(table_name, options)
    unless index_exists?(table_name, index_name, true)
      Rails.logger.warn("Index name '#{index_name}' on table '#{table_name}' does not exist. Skipping.")
      return
    end
    remove_index!(table_name, index_name)
  end

  def index_name(*args)
    super.shorten(index_name_length, 16)
  end

  def index_name_length
    63
  end

  def drop_not_null_constraint(table_name, column_name, options={})
    table_name = ActiveRecord::Base.table_name_prefix + table_name.to_s
    execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{column_name} DROP NOT NULL")
  end

  def create_not_null_constraint(table_name, column_name, options={})
    table_name = ActiveRecord::Base.table_name_prefix + table_name.to_s
    execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{column_name} SET NOT NULL")
  end

  def with_disabled_contraints
    update "UPDATE pg_class SET reltriggers = 0 WHERE relname IN (SELECT tablename FROM pg_tables WHERE schemaname = current_schema())"
    yield
    update "UPDATE pg_class SET reltriggers=(SELECT COUNT(*) FROM pg_trigger WHERE pg_class.oid=tgrelid) WHERE relname IN (SELECT tablename FROM pg_tables WHERE schemaname = current_schema())"
  end

  def all_property_values_numeric?(table_name, column_name)
    number_of_numeric_values = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{quote_table_name(table_name)} WHERE #{is_number(column_name)} OR #{column_name} IS NULL OR TRIM(#{column_name}) = ''").to_i
    total_number_of_values = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{quote_table_name(table_name)}").to_i
    number_of_numeric_values == total_number_of_values
  end

  def is_number(column_name)
    "TRIM(#{column_name}) ~ '^-?(([0-9]+([.][0-9]*)?)|([0-9]*[.][0-9]+))$'"
  end

  def value_out_of_precision(column_name, precision)
    "#{column_name} ~ '^.*[.][0-9]{#{precision + 1},}$'"
  end

  def __explain__(sql)
    select_all "EXPLAIN #{sql}", "EXPLAIN SQL"
  end

  def insert_large_objects(table, record, new_id, columns=table.columns); end

  def concat(*column_names)
    column_names.join(' || ')
  end

  def bulk_insert(model, data)
    cnames = model.column_names.map(&:downcase)
    cnames.delete('id')
    values = data.map do |row|
      cnames.map { |column_name| row[column_name] }
    end
    inserts = values.map do |row|
      marks = row.map{|v| '?'}.join(', ')
      "(#{marks})"
    end
    column_list = cnames.map{|cname| quote_column_name(cname)}.join(", ")
    sql = %{
      INSERT INTO #{quote_table_name(model.table_name)} (#{column_list})
      VALUES #{inserts.join(", ")}
    }
    execute(SqlHelper.sanitize_sql(sql, *(values.flatten)))
  end

  def insert_multi_rows(table_name, columns, data)
    rows = data.map do |values|
      SqlHelper.sanitize_sql("(#{(['?'] * values.size).join(",")})", *values)
    end

    sql = %Q{
          INSERT INTO #{quote_table_name(table_name)}
                      (#{quote_column_names(columns).join(",")})
               VALUES #{rows.join(",\n")}
    }
    execute(sql)
  end

  # the insert method that came with Rails 2.1 didn't return an id at all times (we need an id for project import); this method will fix that
  # the following method was a commit to the Rails codebase and should be in 2.1.1 (http://github.com/rails/rails/commit/b440aeb54a969ec25228881dd02eb019bbfd7c1e)
  def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
    if insert_id = super
      insert_id
    else
      # Extract the table from the insert sql. Yuck.
      table = sql.split(" ", 4)[2].gsub('"', '')

      # If neither pk nor sequence name is given, look them up.
      unless pk || sequence_name
        pk, sequence_name = *pk_and_sequence_for(table)
      end

      # If a pk is given, fallback to default sequence name.
      # Don't fetch last insert id for a table without a pk.
      if pk && sequence_name ||= default_sequence_name(table, pk)
        last_insert_id(table, sequence_name)
      end
    end
  end

  def create_sequence(name, start, options={})
    if options[:strict_counter]
      execute "CREATE SEQUENCE #{name} INCREMENT 1 START #{start} CYCLE"
    else
      execute "CREATE SEQUENCE #{name} INCREMENT 1 START #{start}"
    end
    execute "SELECT SETVAL('#{name}', #{start}, true)"
  end

  def drop_sequence(name)
    execute "DROP SEQUENCE #{name}"
  end

  def sequence_exists?(name)
    res = execute "SELECT COUNT(*) FROM pg_class where relname = '#{name}'"
    res[0].values[0].to_i != 0
  end

  def next_sequence_value_sql(seq_name)
    "nextval('#{seq_name}')"
  end

  def supports_sequences?
    true
  end

  def set_sequence_value(seq_name, value)
    select "SELECT SETVAL('#{seq_name}', #{value})"
  end

  def last_generated_value(sequence_name)
    current_sequence_value(sequence_name)
  end

  def current_sequence_value(sequence_name)
    select_value("SELECT last_value FROM #{sequence_name}").to_i
  end

  def next_sequence_value(seq_name)
    select_value("SELECT #{next_sequence_value_sql(seq_name)}").to_i
  end

  def true_value
    'TRUE'
  end

  def false_value
    'FALSE'
  end

  def table_exists?(name)
    sql = "SELECT * FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = ?"
    !!self.select_value(SqlHelper.sanitize_sql(sql, name))
  end
end

module PostgresJDBCInsertPatch
  # the insert method in activerecord-jdbc-adapter-0.8.2 does not return an id at all times (we need an id for project import); this method will fix that
  # (this was derived by Mike from a patch for the c-ruby version of insert, seen at http://github.com/rails/rails/commit/b440aeb54a969ec25228881dd02eb019bbfd7c1e)
  def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
    execute(sql, name)
    if id_value
      id_value
    else
      # Extract the table from the insert sql. Yuck.
      table = sql.split(" ", 4)[2]

      # If neither pk nor sequence name is given, look them up.
      unless pk || sequence_name
        pk, sequence_name = *pk_and_sequence_for(table)
      end

      # If a pk is given, fallback to default sequence name.
      # Don't fetch last insert id for a table without a pk.
      if pk && sequence_name ||= default_sequence_name(table, pk)
        last_insert_id(table, sequence_name)
      end
    end
  end

  def quote_string(s)
    super(remove_x0_byte(s))
  end

  # bug 9388, jruby postgres does not handle string including \0 (0x00) well
  def remove_x0_byte(str)
    str.gsub("\0", '')
  end
end

module PostgresAddColumnDefaultFix
  def add_column(table_name, column_name, type, options = {})
    options[:default] = 'false' if options[:default] == false
    super(table_name, column_name, type, options)
  end
end

module MingleOracleJdbcSpec
  def self.extended(base)
    base.extend(JdbcSpec::Oracle)
    base.extend(SmartQuoting)
    base.extend(OracleSupport)
    base.extend(OracleAdapterExtension)
    base.extend(OracleJDBCPatches)
    base.extend(OracleGeneralPatches)
    if base.config[:connection_alive_sql] == 'select 1'
      base.config[:connection_alive_sql] = "select 1 from dual"
    end
    base.config[:retry_count] = 0
  end
end

module MinglePostgreSQLJdbcSpec
  def self.extended(base)
    base.extend(JdbcSpec::PostgreSQL)
    base.extend(PostgresAdapterExtension)
    base.extend(PostgresJDBCInsertPatch)
    base.extend(PostgresAddColumnDefaultFix)
    base.extend(SmartQuoting)
    base.config[:retry_count] = 0
  end
end

module ActiveRecord::ConnectionAdapters
  if RUBY_PLATFORM =~ /java/
    module ::JdbcSpec::Oracle
      def self.adapter_matcher(name, *)
        name =~ /oracle/i ? MingleOracleJdbcSpec : false
      end
    end

    module ::JdbcSpec::PostgreSQL
      def self.adapter_matcher(name, *)
        name =~ /postgre/i ? MinglePostgreSQLJdbcSpec : false
      end
    end
  else
    PostgreSQLAdapter.send(:include, PostgresAdapterExtension, SmartQuoting)
  end
end
