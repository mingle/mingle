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

# Overrides quote method in order to escape string using quoted_string_prefix method, since call to it was removed in rails 2.3.14

if RUBY_PLATFORM =~ /java/ 

  module ActiveRecord
    module ConnectionAdapters
      module Quoting
        def quoted_string_prefix
          'E'
        end

        def quote(value, column = nil)
          # records are quoted as their primary key
          return value.quoted_id if value.respond_to?(:quoted_id)

          case value
            when String, ActiveSupport::Multibyte::Chars
              value = value.to_s
            
              if column && column.type == :binary && column.class.respond_to?(:string_to_binary)
                "'#{quote_string(column.class.string_to_binary(value))}'" # ' (for ruby-mode)
              elsif column && [:integer, :float].include?(column.type)
                value = column.type == :integer ? value.to_i : value.to_f
                value.to_s
              else
                "#{quoted_string_prefix}'#{quote_string(value)}'"
              end
            when NilClass                 then "NULL"
            when TrueClass                then (column && column.type == :integer ? '1' : quoted_true)
            when FalseClass               then (column && column.type == :integer ? '0' : quoted_false)
            when Float, Fixnum, Bignum    then value.to_s
            # BigDecimals need to be output in a non-normalized form and quoted.
            when BigDecimal               then value.to_s('F')
            else
              if value.acts_like?(:date) || value.acts_like?(:time)
                "'#{quoted_date(value)}'"
              else
                "#{quoted_string_prefix}'#{quote_string(value.to_yaml)}'"
              end
          end
        end
      end
    end
  end

end
