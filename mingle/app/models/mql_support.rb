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

module MqlSupport

  KEYWORDS = %w{select distinct * , from tree where tagged with null <= >= < > != = is not ( ) and or in today property group by order asc desc}

  def quote_mql_value(value)
    # unfortunately, MQL can only handle either ' or ", choose which one...
    return "''" if value.nil?
    return "'#{value}'" unless value.to_s.include? "'"
    return value.inspect
  end
  
  def quote_mql_value_if_needed(value)
    mql_value_should_be_quoted(value) ? quote_mql_value(value) : value
  end
  
  def mql_value_should_be_quoted(value)
    return true if value =~ /\W/
    value = value.downcase
    KEYWORDS.detect { |keyword| value == keyword }
  end
  
  module_function :quote_mql_value, :quote_mql_value_if_needed, :mql_value_should_be_quoted
  
  def distinct_property_query(property_name)
    CardQuery.parse("SELECT DISTINCT #{property_name.as_mql} ORDER BY #{property_name.as_mql}")
  end
  
end  
