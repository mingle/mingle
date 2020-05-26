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

class SessionWrapper
  def initialize(raw_session)
    @session = raw_session
  end
  
  def merge!(attributes)
    @session.merge!(convert_boolean_to_string(attributes.stringify_keys))
  end
  
  def each_pair(&block)
    to_hash.each_pair(&block)
  end
  
  def to_hash
    convert_string_to_boolean(@session)
  end
  
  private
  def convert_boolean_to_string(hash)
    hash = hash.dup
    hash.map do |key, value|
      hash[key] = case value 
        when 'true', true
          'true'
        when nil, ''
          nil
        else
          'false'
        end
    end
    hash
  end
  
  
  def convert_string_to_boolean(hash)
    hash = hash.dup
    hash.map do |key, value|
      hash[key] = case value
      when 'true', true
        true
      when nil, ''
        nil
      else
        false
      end
    end
    hash
  end
end
