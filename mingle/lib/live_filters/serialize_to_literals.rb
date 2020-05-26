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

module LiveFilters

  class SerializeToLiterals < Ast::Transform

    class << self
      include Ast

      def apply(ast)
        puts "APPLY: #{ast.inspect}"
        self.new.apply(ast)
      end
    end

    match([any, String, User]) do |op, prop, user|
      [op, prop, user.id.to_s]
    end

    match([any, String, Date]) do |op, prop, date|
      [op, prop, date.strftime("%Y-%m-%d")]
    end

    match([any, String, Card]) do |op, prop, card|
      [op, prop, card.id.to_s]
    end

    match(:project_variable) { |node| puts "node: #{node.inspect}"; node }

  end

end
