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
    class SqlEngine
      delegate :quote_column_name, :quote_table_name, :quote, :lower, :to => :@connection

      def initialize(connection)
        @connection = connection
      end

      def cast_char_to_number(value)
        @connection.as_number(value)
      end

      def cast_timestamp_to_date(value)
        @connection.as_date(value)
      end

      def cast_char_to_date(value)
        "TO_DATE(#{value}, 'YYYY-MM-DD')"
      end
    end
  end
end
