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

module PropertyDefinitionSQL

  def bind
    ::PropertyDefinition.send(:include, PropertyDefinitionSQL::NoJoin)
    ::EnumeratedPropertyDefinition.send(:include, PropertyDefinitionSQL::JoinEnumerationValue)
    ::DatePropertyDefinition.send(:include, PropertyDefinitionSQL::FormatDatetimeToChar)
    ::UserPropertyDefinition.send(:include, PropertyDefinitionSQL::JoinUser)
    ::CardTypeDefinition.send(:include, PropertyDefinitionSQL::JoinCardType)
    ::ProjectPropertyDefinition.send(:include, PropertyDefinitionSQL::JoinProject)
  end
  module_function :bind

  module Base
    def to_select_clause
      "#{join_name}.#{connection.quote_column_name column_name}"
    end

    def to_condition_clause
      to_select_clause
    end

    def quoted_comparison_column
      to_select_clause
    end

    def group_by_columns
      [to_select_clause]
    end

    def order_by_join_sql
      join_sql(order_by_join_name)
    end

    def value_join_sql
      join_sql(join_name)
    end

    def fix_numeric_type_order_by_column_sql(sql)
      if numeric? && column_type.to_s.downcase != 'integer'
        sql = SqlHelper.as_number(sql, project.precision)
      else
        sql
      end
    end

    def mark_case_insensitive(column, sql)
      if 'name' == column.downcase
        SqlHelper.lower(sql)
      else
        sql
      end
    end
  end

  module FormatDatetimeToChar
    include Base
    def to_select_clause
      if self.is_predefined
        "TO_DATE(TO_CHAR(#{join_name}.#{connection.quote_column_name column_name}, 'YYYY-MM-DD'), 'YYYY-MM-DD')"
      else
        super
      end
    end

    def to_condition_clause
      to_select_clause
    end

    def order_by_columns
      [to_select_clause]
    end
  end

  module NoJoin
    include Base
    def join_sql(*args)
    end

    def join_name
      Card.quoted_table_name
    end

    def order_by_join_name
      join_name
    end

    def order_by_columns(as=order_by_join_name)
      [fix_numeric_type_order_by_column_sql(mark_case_insensitive(column_name, "#{Card.quoted_table_name}.#{quoted_column_name}"))]
    end

  end

  module JoinBase
    include Base
    def join_name
      quote_column_name(ruby_name)
    end

    def order_by_join_name
      quote_column_name("order_by_#{column_name}")
    end

    def order_by_columns(as=order_by_join_name)
      order_by_column_names.collect do |column|
        mark_case_insensitive(column, "#{quote_column_name(as)}.#{quote_column_name(column)}")
      end
    end

    protected
    def order_by_column_names
      raise "includer of JoinBase should implement order_by_column_names!"
    end
  end

  module JoinProject
    include JoinBase

    def to_select_clause
      "#{join_name}.#{connection.quote_column_name 'name'}"
    end

    def join_sql(as)
      %{
        LEFT OUTER JOIN #{Project.table_name} #{as} ON #{as}.id = #{Card.quoted_table_name}.project_id
      }
    end

    protected
    def order_by_column_names
      ['name']
    end
  end

  module JoinUser
    include JoinBase
    def to_select_clause
      "#{join_name}.#{connection.quote_column_name 'login'}"
    end

    def join_sql(as)
      %{
        LEFT OUTER JOIN #{User.table_name} #{as} ON #{as}.id = #{Card.quoted_table_name}.#{quoted_column_name}
      }
    end

    protected
    def order_by_column_names
      ["name", "login"]
    end
  end

  module JoinEnumerationValue
    include JoinBase

    def to_select_clause
      "#{join_name}.#{connection.quote_column_name 'value'}"
    end

    def quoted_comparison_column
      numeric? ? "#{Card.quoted_table_name}.#{connection.quote_column_name(column_name) }" : "#{connection.quote_column_name(join_name)}.#{connection.quote_column_name('position')}"
    end

    def join_sql(as)
      %{
        LEFT OUTER JOIN enumeration_values #{as} ON lower(#{as}.value) = lower(#{Card.quoted_table_name}.#{quoted_column_name})
          AND #{as}.property_definition_id = #{id}
      }
    end

    protected
    def order_by_column_names
      ["position"]
    end
  end

  module JoinCardType
    include JoinEnumerationValue
    def to_select_clause
      "#{join_name}.#{connection.quote_column_name 'name'}"
    end

    def join_sql(as)
      %{
        LEFT OUTER JOIN card_types #{as} ON #{as}.name = #{Card.quoted_table_name}.#{quoted_column_name}
          AND #{as}.project_id = #{project.id}
      }
    end
  end

  module JoinCardByNumber
    include JoinBase
    def to_select_clause
      "#{join_name}.#{connection.quote_column_name 'number'}"
    end

    def join_sql(as)
      @card_property_definition.join_sql(as)
    end

    def order_by_column_names
      []
    end
  end
end
