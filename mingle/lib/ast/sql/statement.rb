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
    class InvalidStatementsError < StandardError
    end

    class Statement
      class << self
        STATEMENTS = [:select, :from, :join, :where, :order_by, :group_by]
        MUST_HAVE_STATEMENTS = [:select, :from]
        UNLIMITED_STATEMENTS = [:join]

        STATEMENTS.each_with_index do |m, index|
          define_method(m) do |sql|
            new(sql, index)
          end
        end

        def valid?(statements)
          positions = statements.collect(&:position)
          UNLIMITED_STATEMENTS.each {|s| positions.delete(position(s)) }
          MUST_HAVE_STATEMENTS.all?{|s| positions.include?(position(s))} && positions == positions.uniq
        end

        def validate(statements)
          raise InvalidStatementsError.new(statements.join(' ')) unless valid?(statements)
        end

        def position(statement_name)
          STATEMENTS.index(statement_name)
        end
      end

      attr_reader :sql, :position

      def initialize(sql, position)
        @sql = sql
        @position = position
      end

      def <=>(s)
        @position <=> s.position
      end

      def to_s
        @sql
      end
    end
  end
end
