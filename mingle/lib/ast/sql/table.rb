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

module Ast
  module Sql
    class Table
      attr_reader :name
      alias :table_name :name
      def initialize(name, sql, options)
        @name = name
        @sql = sql
        @options = options
      end

      def alias_name
        @options[:as]
      end

      def column(name, options={})
        @sql.column(name, options.merge(:table => column_table_name))
      end

      def [](column_name)
        column(column_name)
      end

      def column_table_name
        alias_name || @name
      end

      def ==(table)
        table.is_a?(Table) && table.name == self.name && table.alias_name == self.alias_name
      end
      alias :eql? :==

      def hash
        @name.hash * 31 + alias_name.hash
      end

    end
  end
end
