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
  class Rule < Struct.new(:matches, :substitution)
    module InstanceRulesFactory
      def match(*matches, &block)
        Rule.new(matches, block).tap {|r| instance_rules << r}
      end

      def any
        lambda {|n| !n.nil?}
      end

      def not_a_node
        lambda {|n| !n.is_a?(Node)}
      end

      def a_node
        lambda {|n| n.is_a?(Node)}
      end

      def instance_rules
        @instance_rules ||= []
      end
    end

    module Factory
      def self.included(base)
        base.extend(InstanceRulesFactory)
      end
      include InstanceRulesFactory

      def rules
        self.class.instance_rules + instance_rules
      end
    end

    def substitute(node)
      if substitution.arity == 0
        substitution.call
      else
        substitution.call(node.is_a?(Node) ? node.ast : node)
      end
    end

    def match?(node)
      if matches[1] && node.is_a?(Node)
        match_part?(matches[0], node) && match_part?(matches[1], node.ast)
      else
        match_part?(matches[0], node)
      end
    end

    def match_part?(match, node)
      case match
      when Node
        node.is_a?(Node) && node.name == match.name && match_part?(match.ast, node.ast)
      when Class
        node.is_a?(match)
      when Symbol
        node.is_a?(Node) && node.name == match
      when Hash
        node.is_a?(Hash) && match.all? { |k,v| match_part?(v, node[k]) }
      when Array
        if node.is_a?(Array) && node.length == match.length
          match.each_with_index { |m, index| return false unless match_part?(m, node[index]) }
          true
        end
      when Proc
        match.call(node)
      else
        match == node
      end
    end
  end
end
