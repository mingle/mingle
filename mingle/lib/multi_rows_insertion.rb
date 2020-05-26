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

module MultiRowInsertion
  class BulkInsertSqlTemplate
    MAX_SQL_PACKAGE_LENGTH = (1024 * 1024) / 2
    
    def initialize(model, columns_without_primary_key, uniq)
      @connection = ActiveRecord::Base.connection
      @uniq = uniq
      @value_sqls = []
      @columns = columns_without_primary_key
      @model = model
      @base_sql = @connection.generate_base_sql(model.table_name, @columns)
      @total_sql_size = @base_sql.size
    end
    
    def add_value_sql(values_with_quote, sql_types)
      value_sql = @connection.bulk_insert_values_sql(@columns, values_with_quote, sql_types)
      unless @uniq && (!@uniq || @value_sqls.include?(value_sql))
        @value_sqls << value_sql 
        @total_sql_size += value_sql.size + 12
      end
    end
    
    def exceed_package_limit?
      @total_sql_size > MAX_SQL_PACKAGE_LENGTH
    end
    
    def to_sql_without_last_values
      sql = @connection.bulk_insert_sql(@base_sql, @value_sqls[0..-2])
      @value_sqls = [@value_sqls.last]
      @total_sql_size = @base_sql.size + @value_sqls.last.size + 12
      sql
    end
    
    def insert(values_with_quotes)
      values_with_quotes.each do |values_with_quotes|
        add_value_sql(values_with_quotes, bulk_insert_sql_types(@columns))
        bulk_insert_with_sql(to_sql_without_last_values) if exceed_package_limit?
      end
      bulk_insert_with_sql(to_sql)
    end
    
    private
    
    def to_sql
      @connection.bulk_insert_sql(@base_sql, @value_sqls)
    end
    
    def bulk_insert_sql_types(columns)
      columns.collect do |c| 
        case c.sql_type
        when /int\d/  # hack for jruby postgres adapter
          'integer'
        else
          c.sql_type
        end
      end
    end
    
    def bulk_insert_with_sql(sql)
      @connection.insert(sql, "#{@model.name} Bulk Create", nil, nil, @model.sequence_name)
    end
  end
  
  module ActiveRecordClassExt
    def columns_without_primary_key
      columns.select { |c| !c.primary }
    end
    
    def bulk_insert(records, options={})
      return if records.empty?
      columns = columns_without_primary_key
      inserter = MultiRowInsertion::BulkInsertSqlTemplate.new(self, columns, options[:uniq])
      values_with_quotes = records.collect { |record| record.fast_attributes_with_quotes(columns) }
      inserter.insert(values_with_quotes)
    end
  end
  
  module ActiveRecordInstanceExt
    # we cannot use attributes_with_quotes because it's clone @attributes and quite slow, 
    # but we should make sure we do not change anything on @attributes
    def fast_attributes_with_quotes(columns)
      columns.inject([]) do |result, column|
        result << quote_value(@attributes[column.name], column)
        result
      end
    end
  end
  
  module PostgresqlConnectionExt
    def generate_base_sql(table_name, columns)
      column_names = columns.collect { |c| self.quote_column_name(c.name) }
      "INSERT INTO #{table_name} (#{column_names.join(', ')}) "
    end
    
    def bulk_insert_sql(base_sql, value_sqls)
      "#{base_sql} #{value_sqls.join(' UNION ALL ')}"
    end
    
    def bulk_insert_values_sql(columns, values_with_quotes, sql_types)
      sql = "SELECT "
      values_with_quotes.each_with_index do |value, index|
        sql << " CAST(#{value} as #{sql_types[index]}),"
      end
      sql.chop! if sql.ends_with?(',')
      sql
    end
  end
  
  module OracleConnectionExt
    def generate_base_sql(table_name, columns)
      insert_columns = columns.collect { |c| self.quote_column_name(c.name) }
      select_columns = build_aliases(columns.size)
      
      if self.prefetch_primary_key?
        insert_columns.unshift('id')
        select_columns.unshift(self.next_id_sql(table_name))
      end
      
      "INSERT INTO #{table_name} (#{insert_columns.join(', ')}) SELECT #{select_columns.join(', ')} FROM "
    end
    
    def bulk_insert_sql(base_sql, value_sqls)
      "#{base_sql} (#{value_sqls.join(' UNION ALL ')})"
    end
    
    def bulk_insert_values_sql(columns, values_with_quotes, sql_types)
      aliases = build_aliases(columns.size)
      
      sql = "SELECT "
      values_with_quotes.each_with_index do |value, index|
        sql << " CAST(#{value} as #{sql_types[index]}) as #{aliases[index]},"
      end
      sql.chop! if sql.ends_with?(',')
      sql << " FROM DUAL"
    end
    
    private
    
    def build_aliases(number)
      (1..number).collect { |n| "a#{n}" }
    end
  end
end


class ActiveRecord::Base
  class << self
    include MultiRowInsertion::ActiveRecordClassExt
  end
  include MultiRowInsertion::ActiveRecordInstanceExt
end

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  include MultiRowInsertion::PostgresqlConnectionExt
end

class ActiveRecord::ConnectionAdapters::OracleAdapter
  include MultiRowInsertion::OracleConnectionExt
end

if RUBY_PLATFORM =~ /java/
  module JdbcSpec::PostgreSQL
    include MultiRowInsertion::PostgresqlConnectionExt
  end
  
  module JdbcSpec::Oracle
    include MultiRowInsertion::OracleConnectionExt
  end
end
