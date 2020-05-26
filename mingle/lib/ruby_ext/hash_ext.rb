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

class Hash
  def filter_by(another_hash)
    return self.clone unless another_hash && !another_hash.empty?
    result = self.clone
    result.delete_if { |my_key, my_value| another_hash.key?(my_key) && another_hash[my_key] == my_value}
    result
  end
  
  def contains?(another_hash)
    (another_hash || {}).filter_by(self).empty?
  end
  
  def find_ignore_case(search_key)
    result_pair = detect{|key, value| key.to_s.downcase == search_key.to_s.downcase}
    result_pair ? result_pair.last : nil
  end

  def find_by_numeric_key(key)
    return self[nil] if key.blank?
    return self[key] unless key.numeric? && !self.include?(key)
    numerically_equivalent_key = self.keys.compact.sort.detect { |k| k.numeric? && BigDecimal.new(k.to_s.trim) == BigDecimal.new(key.to_s.trim) }
    self[numerically_equivalent_key] if numerically_equivalent_key
  end
  
  def delete_ignore_case(key)
    key, value = detect{|k, v| k.to_s.downcase == key.to_s.downcase}
    delete(key) unless key.nil?
    value
  end
  
  def reject_all(value_to_reject)
    reject{|key, value| value == value_to_reject}
  end  
  
  def reject_all!(value_to_reject)
    reject!{|key, value| value == value_to_reject}
  end
  
  def transform_keys(&transformation)
    Hash[*self.collect { |k,v| [transformation.call(k), v] }.flatten]
  end
  
  def concatenative_merge(new_hash)
    new_key_value_pairs = new_hash.collect do |k, v|
      new_value = if (old_value = self[k])
        [old_value, v].join(' ')
      else
        v
      end
      [k, new_value]
    end
    self.merge(Hash[*new_key_value_pairs.flatten])
  end
  
  def joined_ordered_values_by_smart_sorted_keys(join_string=',')
    hash = self.dup.stringify_keys
    result = hash.keys.sort.inject([]) do |accumulator, key|
      value = hash[key]
      next accumulator if value.blank? && ![true, false].include?(value)
      values = if value.is_a?(Array)
        value.smart_sort.collect(&:downcase)
      elsif value.is_a?(String)
        value.split(',').smart_sort.collect(&:downcase)
      elsif value.is_a?(Hash)
        ["{#{value.joined_ordered_values_by_smart_sorted_keys(join_string)}}"]
      else
        [value]
      end
      accumulator << "#{key}=#{values.flatten.join(',')}"
    end
    result.join(join_string)
  end  
  
  def stringify_number_values
    inject({}) do |options, (key, value)|
      if value.is_a?(Fixnum)
        options[key] = value.to_s
      elsif value.is_a?(Float) && value.to_s =~ /(\d+)\.0+$/
        options[key] = $1
      else
        options[key] = value
      end
      options
    end
  end
end
