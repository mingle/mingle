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

module OracleEnhancedAdapterExtensions

  def self.included(base_class)
    base_class.prepend ShortIdentifiers, StatementStrip, CurrentSchemaIndexes, SmartQuoting, ClobSupport
    base_class.include ::AdapterHelpers
  end

  def database_vendor
    :oracle
  end

  def switch_schema(schema_name)
    schema_name = schema_name.upcase
    @connection.instance_variable_set(:@owner, schema_name) if execute("ALTER SESSION SET CURRENT_SCHEMA = #{schema_name}")
  end

  def schema_exists?(schema_name)
    select_value(SqlHelper.sanitize_sql('SELECT USERNAME FROM ALL_USERS WHERE USERNAME = ?', schema_name.upcase)) == schema_name.upcase
  end

  def next_id_sql(table_name)
    "#{default_sequence_name(table_name, nil)}.nextval"
  end

  def schemata_with_prefix(prefix)
    select_values SqlHelper.sanitize_sql("SELECT USERNAME FROM ALL_USERS WHERE USERNAME LIKE ? ESCAPE '\\'", "#{prefix.upcase}%")
  end

  def create_tenant_schema(schema_name)
    password = "p#{SecureRandom.hex[0..15]}"
    execute("CREATE USER #{schema_name} IDENTIFIED BY #{password} DEFAULT TABLESPACE users QUOTA UNLIMITED ON users TEMPORARY TABLESPACE temp")
  end

  def drop_tenant_schema(schema_name)
    execute("DROP USER #{schema_name} CASCADE")
    result = select_value("SELECT COUNT(*) AS TABLESPACE_COUNT FROM DBA_TABLESPACES WHERE TABLESPACE_NAME='#{schema_name}'")
    execute("DROP TABLESPACE #{schema_name} INCLUDING CONTENTS AND DATAFILES") if result.to_i > 0
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
    'NUMBER'
  end

  def string_limit
    4000
  end

  def safe_table_name(proposed_name)
    shorten_table(super(proposed_name))
  end

  def column_name(column_name)
    shorten_column(column_name)
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
    res = select_value "SELECT COUNT(*) FROM user_sequences WHERE sequence_name = '#{shorten_table(name.to_s.upcase)}'"
    res.to_i != 0
  end

  def set_sequence_value(sequence_name, value)
    drop_sequence(sequence_name)
    create_sequence(sequence_name, value)
  end

  def last_generated_sequence_value(sequence_name)
    select_value("SELECT LAST_NUMBER FROM USER_SEQUENCES WHERE LOWER(SEQUENCE_NAME)=LOWER('#{sequence_name}')").to_i
  end

  def current_sequence_value(sequence_name)
    select_value("select #{sequence_name}.CURRVAL from dual").to_i
  end

  def not_null_or_empty(column)
    "#{column} IS NOT NULL"
  end

  def datetime_insert_sql(value)
    if value.blank?
      'NULL'
    elsif value.acts_like?(:time) && value.respond_to?(:usec)
      "TO_TIMESTAMP('#{value.to_formatted_s(:db)}.#{sprintf('%06d', value.usec)}', 'YYYY-MM-DD HH24:MI:SS.FF')"
    else
      "TO_DATE('#{value}', 'YYYY-MM-DD HH24:MI:SS')"
    end
  end

  def alias_if_necessary_as(_)
    ''
  end

  def as_char(value, size)
    value = 'NULL' if value.blank?
    "CAST(#{value} AS VARCHAR2(#{size}))"
  end

  def as_boolean(value)
    "CAST(#{value} AS NUMBER(1,0))"
  end

  def as_padded_number(value, precision)
    value = 'NULL' if value.blank?
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
      cnames.map {|column_name| [column_name, row[column_name]]}
    end

    first_insert = select_from_dual(values[0].map {|cname, value| "? as #{quote_column_name(cname)}"}.join(', '))
    rest = values[1..-1].map do |row|
      select_from_dual(row.map {|_, value| '?'}.join(', '))
    end

    sql = %{
      INSERT INTO #{quote_table_name(model.table_name)}
             SELECT #{id_sql}, #{quoted_cnames.join(', ')}
             FROM (#{[first_insert, rest].flatten.join(' UNION ALL ')})
    }

    values_without_cname = values.map {|row| row.map {|_, value| value}}
    execute(SqlHelper.sanitize_sql(sql, *(values_without_cname.flatten)))
  end

  def insert_multi_rows(table_name, columns, data)
    rows = data.map do |values|
      sql = SqlHelper.sanitize_sql("select #{(['?'] * values.size).join(",\n")} from dual", *values)
      # need to convert empty_clob() to '' to avoid ORA-01790 issue with union and data types
      sql.gsub('empty_clob()', "''")
    end

    sql = %Q{
        INSERT INTO #{quote_table_name(table_name)}
          (#{quote_column_names(columns).join(",\n")})
          #{rows.join("\nUNION ALL ")}
    }
    execute(sql)
  end

  # we need the insert method to return an id (project import needs this), and this patch does that.  it's based on the postgresql patch.
  def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds=[])
    if insert_id = super
      insert_id
    else
      # Extract the table from the insert sql. Yuck.
      table = sql.split(' ', 4)[2].gsub('"', '')

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

  def value_out_of_precision(column_name, precision)
    "REGEXP_LIKE(#{quote_column_name(column_name)}, '^.*[.][0-9]{#{precision + 1},}$')"
  end

  def from_no_table
    'FROM dual'
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

  module ShortIdentifiers
    def indexes(table, name = nil)
      super(shorten_table(table), name)
    end

    def index_name(table_name, options)
      super(table_name, options)
    end

    def add_index(table_name, column_name, options = {})
      options[:name] = shorten_table(options[:name]) if options[:name]
      column_names = Array(column_name).map {|name| shorten_column(name)}
      super(shorten_table(table_name), column_names, options)
    end

    def default_sequence_name(table, column = nil)
      super(shorten_table(table), column)
    end

    def add_column(table_name, column_name, type, options = {})
      super(shorten_table(table_name), shorten_column(column_name), type, char_ify_limit(type, options))
    end

    def rename_column(table_name, column_name, new_column_name)
      super(shorten_table(table_name), shorten_column(column_name), shorten_column(new_column_name))
    end

    def change_column_default(table_name, column_name, default)
      super(shorten_table(table_name), shorten_column(column_name), default)
    end

    def change_column(table_name, column_name, type, options = {})
      super(shorten_table(table_name), shorten_column(column_name), type, char_ify_limit(type, options))
    end

    def remove_column(table_name, column_name)
      super(shorten_table(table_name), shorten_column(column_name))
    end

    def columns(table_name, name = nil)
      super(shorten_table(table_name), name)
    end

    def create_table(table_name, options = {}, &block)
      options[:sequence_name] = shorten_table(options[:sequence_name]) if options[:sequence_name]
      super(shorten_table(table_name), options, &block)
    end

    def rename_table(table_name, new_name)
      super(shorten_table(table_name), shorten_table(new_name))
    end

    def drop_table(name, options = {})
      options[:sequence_name] = shorten_table(options[:sequence_name]) if options[:sequence_name]
      super(shorten_table(name), options)
    end

    def data_source_exists?(table_name)
      super(shorten_table(table_name))
    end

    def quote_column_name(column_name)
      super(shorten_column(escape_keyword(column_name)))
    end

    def quote_table_name(table_name)
      super(shorten_table(table_name))
    end

    def pk_and_sequence_for(table_name, owner=nil, desc_table_name=nil, db_link=nil)
      super(shorten_table(table_name), owner, desc_table_name, db_link)
    end
  end

  # varchar to clob column is not supported in oracle. Copying this patch from rails 2 until oracle enhanced fixes it
  # https://github.com/rsim/oracle-enhanced/issues/1675
  module ClobSupport
    def change_column(table_name, column_name, type, options = {})
      if type == :text
        temp_column_name = "#{column_name}_temp"
        add_column(table_name, temp_column_name, :text, options)
        execute "UPDATE #{quote_table_name(table_name)} set #{quote_column_name(temp_column_name)} = #{quote_column_name(column_name)}"
        remove_column(table_name, column_name)
        rename_column(table_name, temp_column_name, column_name)
      else
        super(table_name, column_name, type, options)
      end
    end
  end

  module SmartQuoting
    def quote_column_name(full_name)
      tokens = full_name.to_s.split('.')
      return super(full_name) if tokens.size < 2
      table_name, column_name = tokens
      [table_name, super(column_name)].join('.')
    end

    def quote_column_name(name)
      return name if name.to_s.starts_with?(ActiveRecord::Base.connection.quote_character) && name.to_s.ends_with?(ActiveRecord::Base.connection.quote_character)
      super(name)
    end

    def quote_table_name(name)
      return name if name.to_s.starts_with?(ActiveRecord::Base.connection.quote_character) && name.to_s.ends_with?(ActiveRecord::Base.connection.quote_character)
      super(name)
    end

  end

  module StatementStrip
    def execute(sql, name=nil)
      sql = sql[0..-2] if sql.end_with?(';')
      super(sql, name)
    end
  end

  module CurrentSchemaIndexes
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
      sql = 'select index_name from all_indexes where index_name = ? and owner = ?'
      self.select_value(SqlHelper.sanitize_sql(sql, index_name.upcase, Multitenancy.schema_name.upcase))
    end

  end

  private
  def escape_keyword(column_name)
    column_name = column_name.to_s.upcase if %w(file number comment size user date).include?(column_name.to_s.downcase.split('.').last)
    column_name
  end



  def char_ify_limit(type, options)
    if type.to_sym == :string && options[:limit] && options[:limit].numeric?
      options[:limit] = "#{options[:limit]} CHAR"
    end
    options
  end

  def select_from_dual(content)
    "select #{content} from dual"
  end

end

module AdapterHelpers
  IDENTIFIER_LIMIT = 30
  SEQUENCE_POSTFIX_LENGTH = 4 # _seq

  def shorten_table(name)
    name = name.to_s
    table_identifier_limit = name.downcase.end_with?('_seq') ? IDENTIFIER_LIMIT : IDENTIFIER_LIMIT - SEQUENCE_POSTFIX_LENGTH
    return name if name.size <= table_identifier_limit

    name[0..9] + Digest::SHA1.hexdigest(name)[0..15]
  end

  def shorten_column(name)
    return name if name.to_s.size <= IDENTIFIER_LIMIT
    name = name.to_s
    name[0..13] + Digest::SHA1.hexdigest(name)[0..15]
  end
end

module OracleEnhancedJDBCConnectionExtensions
  def self.included(base_class)
    base_class.prepend ClassMethods
    base_class.include ::AdapterHelpers
  end

  module ClassMethods
    def describe(table_name)
      super(shorten_table(table_name))
    end
  end
end


ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval do
  include OracleEnhancedAdapterExtensions
end

ActiveRecord::ConnectionAdapters::OracleEnhancedJDBCConnection.class_eval do
  include  OracleEnhancedJDBCConnectionExtensions
end
