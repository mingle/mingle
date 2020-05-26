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

module SmartSort
  class Key
    attr_reader :str
    
    def initialize(str, is_number)
      @str = str
      @is_number = is_number
    end
    
    def <=>(another_key)
      if another_key.number? && self.number?
        self.str.to_i <=> another_key.str.to_i
      else
        self.str <=> another_key.str
      end
    end
    
    def number?
      @is_number
    end
  end
  
  def smart_sort
    raise 'Please use #smart_sort_by' if block_given?
    sort{|left, right| SmartSort.compare_keys(left, right)}
  end

  def smart_sort_by(&block)
    sort{|left, right| SmartSort.compare_keys(block.call(left), block.call(right))}
  end
  
  class << self
    def compare_keys(left, right)
      left_a = numeric_split(left.to_s.downcase)
      right_a = numeric_split(right.to_s.downcase)
      left_a <=> right_a
    end

    def numeric_split(op)
      nums = op.scan(/\d+/)
      strs = op.split(/\d+/)
      result = []
      until nums.size == 0  && strs.size == 0
        if (str = strs.shift) && (str != '')
          result << Key.new(str, false)
        end
        if (num = nums.shift) && (num != '')
          result << Key.new(num, true)
        end
      end    
      result
    end
  
  end
end
