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
  class Transform
    include Rule::Factory

    class << self;
      def project
        Project.current
      end
    end

    def initialize(&block)
      block.call(self) if block_given?
    end

    def apply(ast)
      try_rules ast
    end

    private
    def expand(ast)
      case ast
      when Node
        Node.new(ast.name, apply(ast.ast))
      when Array
        ast.collect {|node| apply(node)}
      when Hash
        ast.inject({}) do |memo, entry|
          key, value = entry
          memo[key] = apply(value)
          memo
        end
      else
        ast
      end
    end

    def try_rules(node)
      if rule = self.rules.find { |rule| rule.match?(node) }
        rule.substitute(expand(node))
      else
        expand(node)
      end
    end
  end
end
