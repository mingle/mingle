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


module Stripper
  def sanitize_string_value(value)
    case value
    when String
      HTML::FullSanitizer.new.sanitize(value)
    when Hash
      value.each do |key, v|
        value[key] = sanitize_string_value(v)
      end
    when Array
      value.map do |item|
        sanitize_string_value(item)
      end
    else
      value
    end
  end

  extend self
end
