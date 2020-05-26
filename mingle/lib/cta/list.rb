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

module CTA

  class List < Ast::Transform
    class << self
      include Ast

      def apply(ast)
        self.new.apply(ast)
      end
    end

    match(:statements) {|node| node.find{|n| n.name == :where}.try(:ast) }

    match(:and) { |node| ['and'] + node }
    match(:or) { |node| ['or'] +  node }

    match(:comparision, [UserPropertyDefinition, any, String]) do |prop, op, login|
      [op, prop.name, project.users.find_by_login(login.downcase)]
    end
    match(:comparision, [CardRelationshipPropertyDefinition, any, String]) do |prop, op, name|
      [op, prop.name, project.cards.find_by_name(name)]
    end
    match(:comparision, [DatePropertyDefinition, any, String]) do |prop, op, date|
      [op, prop.name, date.downcase == 'today' ? Date.today : Date.parse_with_hint(date, Project.current.date_format)]
    end

    match(:comparision) { |prop, op, value| [op, prop.name, value] }
    match(:card_number) do |node|
      case node
      when Array
        node.map { project.cards.find_by_number(node) }
      else
        project.cards.find_by_number(node.to_i)
      end
    end
    match(:null) { |node| nil }
    match(:literals) { |node| node }

    # match(:not) { |node| ['not'] + node }
    match(:in) do |node|
      prop = node[:property]
      values = node[:values]

      case values.size
      when 0
        false
      when 1
        apply(node(:comparision, [prop, "=", values.first]))
      else
        ["in", prop.name, values]
      end
    end
    # match(:tagged) { |node| ['tagged with'] + node[:with] }
    match(:context, :type => 'user') {|node| User.current}
    # match(:context, :type => 'card') { |node| raise "Unsupported keyword: THIS CARD" }
  end
end
