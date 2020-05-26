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

module PostgreSQLAdapterExtensions

  def database_vendor
    :postgresql
  end

  def switch_schema(schema_name)
    execute("SET SESSION search_path TO #{schema_name.downcase}")
  end

  def case_insensitive_inequality(value_one, value_two)
    "LOWER(CAST(#{value_one} AS TEXT)) != LOWER(CAST(#{value_two} AS TEXT))"
  end

  def schema_exists?(schema_name)
    select_value("SELECT nspname FROM pg_namespace WHERE lower(nspname) = '#{schema_name.downcase}'")
  end

  def schemata_with_prefix(prefix)
    select_values SqlHelper.sanitize_sql("SELECT nspname FROM pg_namespace WHERE lower(nspname) LIKE ? ESCAPE '\\'", "#{prefix.downcase}%")
  end

  # arbitrary precision when neither precision and scale are specified
  def high_precision_number_type
    'NUMERIC'
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

  def index_name(*args)
    super.shorten(index_name_length, 16)
  end

  def all_property_values_numeric?(table_name, column_name)
    number_of_numeric_values = ActiveRecord::Base.connection.select_value(SqlHelper.sanitize_sql_for_conditions("SELECT COUNT(*) FROM #{quote_table_name(table_name)} WHERE #{is_number(column_name)} OR #{column_name} IS NULL OR TRIM(#{column_name}) = ''")).to_i
    total_number_of_values = ActiveRecord::Base.connection.select_value(SqlHelper.sanitize_sql_for_conditions("SELECT COUNT(*) FROM #{quote_table_name(table_name)}")).to_i
    number_of_numeric_values == total_number_of_values
  end

  def is_number(column_name)
    "TRIM(#{column_name}) ~ '^-?(([0-9]+([.][0-9]*)?)|([0-9]*[.][0-9]+))$'"
  end

  def value_out_of_precision(column_name, precision)
    "#{column_name} ~ '^.*[.][0-9]{#{precision + 1},}$'"
  end

  def bulk_insert(model, data)
    column_names = model.column_names.map(&:downcase)
    column_names.delete('id')
    values = data.map do |row|
      column_names.map { |column_name| row[column_name] }
    end
    insert_multi_rows(model.table_name, column_names, values)
  end

  def insert_multi_rows(table_name, columns, data)
    rows = data.map do |values|
      SqlHelper.sanitize_sql("(#{(['?'] * values.size).join(',')})", *values)
    end

    sql = %Q{INSERT INTO #{quote_table_name(table_name)} (#{quote_column_names(columns).join(',')})
      VALUES #{rows.join(",\n")}}
    execute(sql)
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

  def append_to(column_name)
    "#{quote_column_name(column_name)} || (?)"
  end

  def next_id_sql(table_name)
    next_sequence_value_sql(default_sequence_name(table_name, nil))
  end

end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  include PostgreSQLAdapterExtensions

  alias_method :create_tenant_schema, :create_schema
  alias_method :drop_tenant_schema, :drop_schema
  alias_method :last_generated_value, :current_sequence_value
end
