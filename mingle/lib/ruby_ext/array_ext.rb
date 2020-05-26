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

class Array
  include SmartSort

  def ensure_size(size, filler='')
    self.size.upto(size - 1){self << filler}
  end

  def collect_with_index(&block)
    ret = []
    each_with_index{ |member, index| ret << yield(member, index) }
    ret
  end

  def average
    self.inject(0){|acc, el| acc + el.to_i}.to_f / size.to_f
  end

  def shuffle
    ret = clone
    (ret.size - 1).downto(1) do |i|
      j = Kernel.rand(i + 1)
      ret[i], ret[j] = ret[j], ret[i]
    end
    ret
  end

  def collect_slice(size, &block)
    results = []
    each_slice(size) do |elements|
      results << yield(elements)
    end
    results
  end

  def each_pair(&block)
    each_with_index do |element, index|
      if index < length - 1
        yield(element, self[index + 1])
      end
    end
  end

  def without(element)
    result = self.dup
    result.delete(element)
    result
  end

  def extract!(&block)
    yes, no = partition(&block)
    replace(no)
    yes
  end

  def contains_all?(other)
    other.respond_to?(:to_ary) && (other.to_ary - self).empty?
  end

  def intersect(another)
    result = []
    for element in self
      result << element if another.include?(element)
    end
    result.uniq!
    result
  end

  def none?(&block)
    !any?(&block)
  end

  def not_all?(&block)
    !all?(&block)
  end

  def split_by(&block)
    return self.select(&block), self.reject(&block)
  end

  def reject_all(value_to_reject)
    reject{|value| value == value_to_reject}
  end

  def reject_all!(value_to_reject)
    reject!{|value| value == value_to_reject}
  end

  def ignore_case_include?(element)
    any?{|one| one.ignore_case_equal?(element)}
  end

  def ignore_case_delete!(element)
    reject!{|one| one.ignore_case_equal?(element)}
  end

  def ignore_case_delete(element)
    reject{|one| one.ignore_case_equal?(element)}
  end

  def group_into_blocks_of_size(group_size)
    non_flat_array = []
    each_with_index do |first_option, index|
      non_flat_array << [first_option] + self[(index + 1) .. (index + group_size - 1)] if index % group_size == 0
    end
    non_flat_array
  end

  def sort_with_nil_by(&block)
    nil_value, not_nil_value = partition{|e| yield(e).nil? }
    nil_value + not_nil_value.sort_by{|e| yield(e) }
  end

  def groups_of(group_size, &block)
    [].tap do |result|
      each_with_index do |element, index|
        stop_index = (index + group_size)
        if block_given?
          result << self[index..(stop_index-1)] if yield self[index..(stop_index-1)]
        else
          result << self[index..(stop_index-1)]
        end
        break if stop_index >= size
      end
    end
  end

  def bold
    collect(&:bold)
  end

  def sorted_bold_sentence
    smart_sort.collect(&:bold).to_sentence
  end

  def second
    self[1]
  end

  def duplicates?
    !duplicates.empty?
  end

  def duplicates
    select{ |x| grep(x).size > 1 }.uniq
  end

  def sequence_pairs
    shifted = self.dup.unshift(nil)
    pairs = shifted.zip(self)
    pairs[1..-2] || []
  end

  def join_with_prefix(prefix_and_separator)
    "#{(empty? ? '' : prefix_and_separator)}#{join(prefix_and_separator)}"
  end

  def plural(size)
    self.collect { |item| item.plural(size) }.join(' ')
  end

  def upcase_dup
    self + self.collect { |e| e.upcase }
  end

  def equivalent?(other_array)
    self.sort == other_array.sort
  end

  def shift_each!(&block)
    while e = self.shift
      block.call(e) if block_given?
      self.delete(e)
    end
  end

end
