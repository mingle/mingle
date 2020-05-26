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

class RoundtripJoinableArray < DelegateClass(Array)
  def self.from_array(array)
    self.new((array || []))
  end
  
  def self.from_str(str)
    self.new(split_by_comma(str.to_s || ''))
  end

  def to_s
    join_with_comma
  end

  private
  
  def join_with_comma
    compact.uniq.collect{|element|element.gsub(/\\/, '\\\\\\\\').gsub(/,/, '\\,')}.join(',')
  end
  
  def self.split_by_comma(str)
    result = []
    one = []
    escape = false
    str.each_char do |char|
      if escape
        escape = false
        one << char
      elsif(char == ',')
        result << one.join
        one = []
      elsif (char == '\\')
        escape = true
      else
        one << char
      end
    end
    result << one.join unless one.blank?
    result
  end
end
