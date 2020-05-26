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

class DoneStatusDefinition
  
  def initialize(minimum_done_status)
    @minimum_done_status = minimum_done_status
  end
    
  def as_mql
    "'#{@minimum_done_status.name}' #{operator.to_s} '#{@minimum_done_status.value}'"
  end

  def operator
    :>=
  end
  
  def status_name
    @minimum_done_status.name
  end
    
  def includes?(status_value)
    property_definition = @minimum_done_status.property_definition
    property_definition.sort_position(status_value) >= property_definition.sort_position(@minimum_done_status.value)
  end
  
end
