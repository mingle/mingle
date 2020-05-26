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
    # Transforms a mql ast in a project context to a list of columns used for collecting mql ast query result
    # This module is defined as an (plan/project) query interface for Selector to collect db result
    module SelectColumns
      def collect_select_columns(mql, project)
        mql.transform do |t|
          t.match(:statements) do |node|
            if select = node.find {|statement| statement.name == :select}
              select.ast[:columns]
            end
          end
          t.match(:aggregate) do |node|
            node(:aggregate, :numeric => true, :name => aggregate_alias_name(node), :property => node[:property], :function => node[:function])
          end
          t.match('*') {|star| column(star, :numeric => true)}
          t.match(:property) do |node|
            prop = project.find_property_definition_or_nil(node[:name])
            column(node[:name], :type => prop.class, :numeric => numeric_prop?(prop))
          end
        end
      end

      def date_type_column?(column)
        column.ast[:type] == DatePropertyDefinition
      end

      def user_type_column?(column)
        column.ast[:type] == UserPropertyDefinition
      end

      def numeric_type_column?(column)
        column.ast[:numeric]
      end

      def aggregate_column?(column)
        column.name == :aggregate
      end

      def max_or_min_aggregate_column?(column)
        aggregate_column?(column) && column.ast[:function] =~ /^(max|min)$/i
      end

      def aggregate_alias_name(node)
        "#{node[:function]}(#{node[:property].ast[:name]})"
      end

      def numeric_prop?(prop)
        prop.numeric? || false
      end
    end
  end
end
