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

class Heuristics
  
  def initialize(contents)
    @contents = contents
  end  
  
  def index_of(which_columns = nil, with_criteria = nil)
    return nil unless which_columns && with_criteria
    send(which_columns, ranks(with_criteria), @contents.size)
  end 
  
  def ranks(with_criteria)
    match_grid = @contents.cells.collect { |line| self.send(with_criteria, line) }
    match_grid.transpose.collect(&:sum)
  end
  
  private
  def two_words(line)
    line.collect {|value| value =~ /^(\w+(\s|$)){2}$/ ? 1 : 0}
  end  
  
  def many_words(line)
    line.collect {|value| value =~ /^(\w+(\s|$)){4,}|\d*\s{1,}$/ ? 1 : 0}
  end
  
  def diverse_words(line)
    line.collect {|value| value =~ /^\w+$/ ? 1 : 0}
  end  
  
  def number_column(line)
    line.collect {|value| (value.nil? || value =~ /^\#*(\d+)$/ and value.to_i.is_a?(Fixnum)) ? 1 : 0}
  end
  
  def all_numeric(line)
    line.collect {|value| (value.blank? || value.numeric? and value.to_i.is_a?(Fixnum)) ? 1 : 0}
  end  
  
  def less_than_three_words(line)
    line.collect {|value| (value.nil? || value =~  /^((\w\S*)(\s|$)){0,3}$/) ? 1 : 0}
  end 
  
  def verbose_content(line)
    line.collect { |value| (value || '').bytes.count > 255 ? 1 : 0 }
  end  
  
  def date_values(line)
    line.collect do |value|
      valid_date = !Date._parse(value || '', false).
          values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :wday)[0..2].any?(&:blank?)
      value.blank? || valid_date ? 1 : 0
    end    
  end 
  
  def empty(line)
    line.collect {|value| value.nil? ? 1 : 0}
  end
  
  def only_first_column(matches, rank)
    return matches[0] == rank ? 0 : nil
  end
  
  def first_non_zero_column(matches, rank)
    index = 0
    while (index < matches.size ) do
      return index if matches[index] > 0
      index = index.next
    end
    nil
  end
  
  def all_columns(matches, rank)
    all_columns_with(matches, rank) { |number_of_matches| number_of_matches > 0 }
  end
  
  def all_columns_with(matches, rank)
    result = []
    index = 0
    while (index != matches.size ) do
      result << index if yield(matches[index])
      index = index.next
    end  
    return result
  end      

  def all_columns_with_full_match(matches, rank)
    all_columns_with(matches, rank) { |number_of_matches| number_of_matches == rank }
  end
  
  def diverse_columns(matches, rank)
    #We have to create a new array with the contents, because JRuby is unable to transpose the @contents array directly.
    [].tap do |result|
      @contents.columns.each_with_index do |column, index|
        has_more_than_ten_distinct_non_empty_values = column.reject(&:blank?).uniq.size > 10
        result << index if has_more_than_ten_distinct_non_empty_values && (matches[index] == rank)
      end
    end
  end
  
end
