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

class DatabaseErrorConverter
  
  DEFAULT_HOST_OR_PORT_ERROR_MESSAGE = %{Check that the hostname and port are correct.}
  
  def self.convert(error)
    origin_message = if error.message =~ /^The driver encountered an error:(.*)/m
      $1.strip
    else
      error.message
    end
    
    case origin_message
    when /org.postgresql.util.PSQLException: ?(Connection refused.|FATAL\:)?(.*)/
      $2.strip
    when /Null user or password not supported in THIN driver/
      "Check that the machine name and listener port are correct"
    when /does not currently know of SID given in connect descriptor/
      "Check that the database instance name is correct"
    when /Io exception: The Network Adapter could not establish/
      "Check that the machine name and listener port are correct"
    when /invalid username\/password/
      "Check that your username and password are correct"
    when /.*Exception:(.*)/
      $1.strip
    else
      origin_message
    end
  end
end
