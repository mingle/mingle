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

class Plan
  module Query
    # Selector takes a db connection, query object and formatter
    # transforms query sql ast to sql string, and collect & format db result
    # 
    # Arguments
    #   query:
    #     sql_ast
    #     select_columns
    #     date_type_column?
    #     numeric_type_column?
    #     aggregate_column?
    #     max_or_min_aggregate_column?
    #   formatter:
    #     format_date(date)
    #     format_number(number)
    class Selector
      def initialize(connection, query, formatter)
        @connection = connection
        @query = query
        @formatter = formatter
      end

      def values
        @connection.select_all(self.sql).collect do |row|
          formatted_row = {}
          row.each_pair do |key, value|
            column = @query.select_columns.find {|c| c.ast[:name].downcase == key.downcase}
            formatted_row[key.downcase] = format_column_value column, value
          end
          formatted_row
        end
      end
      
      def single_values
        index = 0
        @connection.select_values(self.sql).map do |value|
          column = @query.select_columns[index]
          index += 1
          format_column_value(column, value)
        end
      end

      def sql
        @sql ||= @query.sql_ast.apply(sql_transformer)
      end

      private
      def format_column_value(column, value)
        return value if column.nil?

        if value.nil?
          return nil unless @query.aggregate_column?(column)
          return nil if @query.max_or_min_aggregate_column?(column)
        end

        case
        when @query.date_type_column?(column)
          value ? @formatter.format_date(Date.parse(value)) : value
        when @query.numeric_type_column?(column)
          @formatter.format_number(value)
        when @query.user_type_column?(column)
          if user = User.find_by_login(value)
            user.name_and_login
          end
        else
          value
        end
      end

      def sql_transformer
        Ast::Sql::Transformer.new(SqlEngine.new(@connection))
      end
    end
  end
end
