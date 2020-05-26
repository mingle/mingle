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
    # PropertyDefinition's data type info
    # because current PropertyDefinition impls don't have a simple match with db data type
    # and I don't want add more small methods into PropertyDefinition large interface, which
    # is confusing already
    module PropertyDefinitionDataType
      include Ast::Sql::DataType

      PROP_COLUMN_TYPE_MAP = {:string => CHAR, :integer => NUMBER}

      def prop_def_data_types(prop)
        column_type = prop_def_column_type(prop)
        {:column_type => column_type, :data_type => prop_def_data_type(prop, column_type)}
      end

      def prop_def_data_type(prop, column_type)
        if prop.numeric?
          NUMBER
        elsif (prop.date? || prop.is_a?(FormulaPropertyDefinition))
          DATE
        else
          column_type
        end
      end

      def prop_def_column_type(prop)
        column_type = is_predefined_date_prop?(prop) ? TIMESTAMP : sql_type(prop.column_type)
      end

      def sql_type(t)
        PROP_COLUMN_TYPE_MAP[t] || t.to_s
      end

      def is_predefined_date_prop?(prop)
        prop.is_predefined && prop.column_type == :date
      end
    end
  end
end
