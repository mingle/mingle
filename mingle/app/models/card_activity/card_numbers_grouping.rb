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

class CardActivity::CardNumbersGrouping
  include SqlHelper
  
  def initialize(original_numbers, grouping_card_query)
    group_by_grouping_conditions(original_numbers, grouping_card_query)
  end
  
  def size
    all_numbers.size
  end
  
  def empty?
    size == 0
  end
  
  def sort_activity_details(details)
    details.sort_by { |d| all_numbers.index(d.number) }
  end
  
  def join(separator)
    all_numbers.join(separator)
  end
  
  def slice(offset, limit)
    all_numbers.slice(offset, limit)
  end
  
  def all_numbers
    @__all_numbers ||= @number_current_matched + @number_was_matched + @number_never_matched
  end
  
  def matching_state_of(number)
    return :current_matched if @number_current_matched.include?(number)
    return :was_matched if @number_was_matched.include?(number)
    :never_matched if @number_never_matched.include?(number)
  end
  
  private
  
  def group_by_grouping_conditions(original_numbers, grouping_card_query)
    if !grouping_card_query || grouping_card_query.conditions.nil?
      @number_current_matched = original_numbers
      @number_was_matched = []
      @number_never_matched = []
      return
    end
    
    ever_matching = numbers_matching_grouping_conditions(original_numbers, grouping_card_query, true)
    current_matching = numbers_matching_grouping_conditions(ever_matching, grouping_card_query)

    @number_current_matched, number_not_current_matched = *original_numbers.partition { |number| current_matching.include?(number) }
    @number_was_matched, @number_never_matched = *number_not_current_matched.partition { |number| ever_matching.include?(number) }
  end
  
  def numbers_matching_grouping_conditions(in_numbers, grouping_card_query, from_version=false)
    oracle_limit = 1000
    in_numbers.collect_slice(oracle_limit) do |sliced_numbers|
      query = numbers_in_query(sliced_numbers, from_version).restrict_with(grouping_card_query)
      sql = from_version ? query.to_card_version_sql : query.to_sql
      select_values(sql).collect(&:to_i)
    end.flatten
  end
  

  def numbers_in_query(in_numbers, distinct)
    number_column = CardQuery::Column.new("Number")
    CardQuery.new(:columns => [number_column], 
                  :conditions => CardQuery::ExplicitIn.new(number_column, in_numbers), 
                  :distinct => distinct)
  end
  
end
