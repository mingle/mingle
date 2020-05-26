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
    class Base < Struct.new(:plan, :mql_string)
      def single_value
        single_values.first
      end
      
      def values
        selector.values
      end

      def single_values
        selector.single_values
      end

      def format_date(date)
        self.plan.format_date(date)
      end

      def format_number(number)
        number.to_s.to_num(self.plan.precision).to_s
      end

      private
      def selector
        @selector ||= Selector.new(Plan.connection, query, self)
      end
      def query
        @query ||= PlanCardQuery.new(plan, Mql.parse(mql_string))
      end
    end
  end
end
