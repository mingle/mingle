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

module Mql
  class StringTransformer < Ast::Transform
    match(:statements) { |node| node.join(' ') }
    match(:select, :distinct => false) { |node| "SELECT #{node[:columns].join(', ')}" }
    match(:select, :distinct => true) { |node| "SELECT DISTINCT #{node[:columns].join(', ')}" }
    match(:aggregate) { |node| "#{node[:function].upcase}(#{node[:property]})" }
    match(:as_of) { |node| 'AS OF ' + node }
    match(:from) { |node| 'FROM TREE ' + node[:trees] }
    match(:where) { |node| "WHERE #{node}" }
    match(:and) { |node| '(' + node.join(' AND ') + ')' }
    match(:or) { |node| '(' + node.join(' OR ') + ')' }
    match(:comparision, [any, any, :property]) { |node| "#{node[0]} #{node[1]} PROPERTY #{node[2]}" }
    match(:comparision) { |node| node.join(' ') }
    match(:not) { |node| 'NOT ' + node }
    match(:project_variable) { |node| "(#{node})"}
    match(:in) { |node| node[:plan] ? 'IN PLAN ' + node[:plan] : "#{node[:property]} IN (#{node[:values]})" }
    match(:tagged) { |node| 'TAGGED WITH ' + node[:with] }
    match(:order_by) { |node| 'ORDER BY ' + node.join(', ') }
    match(:group_by) { |node| 'GROUP BY ' + node.join(', ') }
    match(:card_number) { |node| 'NUMBER ' + node }
    match(:null) { |node| 'NULL' }
    match(:literals) { |node| node.collect{|s| s =~ / / ? s.inspect : s}.join(', ') }
    match(:context, :type => 'user') {|node| 'CURRENT USER'}
    match(:context, :type => 'card') { |node| "THIS CARD#{node[:property] && ".#{node[:property]}"}" }
    match(:property) do |node|
      name = node[:name]
      name = name.inspect if name =~ /\s/
      name = name + ' NUMBER' if node[:key] == 'number'
      name = "#{name} #{node[:order]}" if node[:order]
      name
    end
  end
end
