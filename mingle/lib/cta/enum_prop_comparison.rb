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
  class EnumPropComparison < Ast::Transform
    class << self
      include Ast
      def enum_prop
        lambda do |node|
          node.is_a?(EnumeratedPropertyDefinition)
        end
      end
      def enum_value_index(prop, value)
        value = prop.find_enumeration_value(value)
        prop.values.index(value)
      end
    end

    match(:comparision, [enum_prop, '<', :null]) do |prop, op, _|
      false
    end
    match(:comparision, [enum_prop, '>', :null]) do |prop, op, _|
      values = prop.values.map(&:value)
      node(:in, :property => prop, :values => values)
    end
    match(:comparision, [enum_prop, '>=', :null]) do |prop, op, _|
      values = [nil] + prop.values.map(&:value)
      node(:in, :property => prop, :values => values)
    end
    match(:comparision, [enum_prop, '<=', :null]) do |prop, op, _|
      node(:in, :property => prop, :values => [nil])
    end

    match(:comparision, [enum_prop, '>', any]) do |prop, op, value|
      i = enum_value_index(prop, value)

      if i.nil?
        node(:in, :property => prop, :values => [nil])
      else
        values = prop.values[(i+1)..-1].map(&:value)
        node(:in, :property => prop, :values => values)
      end
    end

    match(:comparision, [enum_prop, '<', any]) do |prop, op, value|
      i = enum_value_index(prop, value)

      if i == 0 || i.nil?
        node(:in, :property => prop, :values => [nil])
      else
        values = [nil] + prop.values[0..(i-1)].map(&:value)
        node(:in, :property => prop, :values => values)
      end
    end

    match(:comparision, [enum_prop, '<=', any]) do |prop, op, value|
      i = enum_value_index(prop, value)

      if i.nil?
        node(:in, :property => prop, :values => [nil])
      else
        values = [nil] + prop.values[0..i].map(&:value)
        node(:in, :property => prop, :values => values)
      end
    end

    match(:comparision, [enum_prop, '>=', any]) do |prop, op, value|
      i = enum_value_index(prop, value)

      if i.nil?
        node(:in, :property => prop, :values => [nil])
      else
        values = prop.values[i..-1].map(&:value)
        node(:in, :property => prop, :values => values)
      end
    end
  end
end
