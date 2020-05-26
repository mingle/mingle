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

module DeliverableImportExport
  module SQLBindSupport
    def insert_bind(statement, values, columns, name = nil, pk = nil, id_value = nil, sequence_name = nil)
      connection.insert(replace_bind_variables(statement, values, columns), name, pk, id_value, sequence_name)
    end

    # Default implementation uses replace_bind_variables
    def update_bind(statement, values, columns, name = nil)
      connection.update(replace_bind_variables(statement, values, columns), name)
    end

    def replace_bind_variables(statement, values, columns) #:nodoc:
      raise_if_bind_arity_mismatch(statement, statement.count('?'), values.size)
      i = -1
      statement.gsub('?') { i+=1 ; quote_bound_value(values[i], columns[i]) }
    end

    def raise_if_bind_arity_mismatch(statement, expected, provided) #:nodoc:
      unless expected == provided
        raise "Wrong number of bind variables (#{provided} for #{expected}) in: #{statement}"
      end
    end

    def quote_bound_value(value, column) #:nodoc:
      if value.respond_to?(:map) && !value.is_a?(String)
        if value.respond_to?(:empty?) && value.empty?
          quote(nil)
        else
          value.map { |v| connection.quote(v) }.join(',')
        end
      else
        connection.quote(value)
      end
    end
  end
end
