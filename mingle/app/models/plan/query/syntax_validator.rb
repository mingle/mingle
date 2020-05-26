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
    class SyntaxValidator < Ast::Transform
      class Error < StandardError
      end

      attr_reader :errors
      def initialize
        match :select, :distinct => true, &unsupported_keyword('DISTINCT')
        match :property, :key => 'number', &unsupported_keyword('NUMBER')
        match :context, :type => 'card', &unsupported_keyword('THIS CARD')
        match :project_variable, &unsupported('PROJECT VARIABLE'.bold)
        match :card_number, &unsupported_keyword('NUMBER')
        match :order_by, &unsupported_keyword('ORDER BY')
        match :group_by, &unsupported_keyword('GROUP BY')
        match :tagged, &unsupported_keyword('TAGGED WITH')
        match :as_of, &unsupported_keyword('AS OF')
        match :from, &unsupported_keyword('FROM TREE')
        match :not, &unsupported_keyword('NOT')
        match(:in) {|node| unsupported_keyword(node[:plan] ? 'IN PLAN' : 'IN').call }
        match :aggregate do |node|
          if node[:function] !~ /^(avg|count|max|min|sum)$/i
            unsupported_aggregate_function(node[:function]).call
          end
        end
        match(:comparision, &unsupported_number_property_in_comparision)
      end

      def validate(mql)
        @errors = []
        mql.apply(self)
        valid?
      end

      def validate!(mql)
        raise Error.new(@errors.first) unless validate(mql)
      end

      def valid?
        @errors.blank?
      end

      private
      def unsupported_keyword(keyword)
        unsupported "Keyword #{keyword.bold}"
      end

      def unsupported_number_property_in_comparision
        lambda  do |node|
          column, op, value = node
          valdate_number_property(column)
          valdate_number_property(value)
        end
      end

      def valdate_number_property(node)
        if node.is_a?(Ast::Node) && node.name == :property && node.ast[:name] =~ /^number$/i
          unsupported("Property #{'Number'.bold} in a 'where' clause").call
        end
      end

      def unsupported(syntax)
        lambda { @errors << "#{syntax} is not supported in plans." }
      end

      def unsupported_aggregate_function(function)
        lambda { @errors << "#{function.bold} is not a recognized aggregate function." }
      end
    end
  end
end
