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

#Copyright 2009 ThoughtWorks, Inc.  All rights reserved.
module CrossProjectRollup
  module Mql
    def build_mql(options={})
      mql = []
      mql << "SELECT"
      mql << "DISTINCT" if options[:select_distinct]
      mql << Array(options[:select_columns]).map(&method(:quote)).join(', ')
      conditions = mql_conditions(*options[:where_conditions])
      mql << "WHERE #{conditions}" unless conditions.blank?
      mql << " GROUP BY #{quote(options[:group_by])}" if options[:group_by]
      mql.join(' ')
    end
    
    def mql_conditions(*conditions)
      conditions = conditions.compact
      return if conditions.empty?
      conditions.compact.map { |condition| "(#{condition})" }.join(' AND ')
    end
    
    def quote(column)
      aggregate?(column) ? column : "'#{column}'"
    end
    
    def aggregate?(column)
      column.to_s =~ /SUM\(/i || column.to_s =~ /COUNT\(/i || column.to_s =~ /AVG\(/i || column.to_s =~ /MIN\(/i || column.to_s =~ /MAX\(/i
    end
  end
end
