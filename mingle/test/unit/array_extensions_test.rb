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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class ArrayExtensionsTest < ActiveSupport::TestCase

  def test_shurffle
    list = (1..1000).to_a
    assert_equal list.sort, list.shuffle.sort
    assert_not_equal list, list.shuffle
    assert_not_equal list.shuffle, list.shuffle
  end

  def test_should_know_if_elements_are_not_equivilent_to_a_subset_of_those_elements
    assert_false [1,2,3].equivalent?([2,3])
  end

  def test_should_know_if_elements_are_not_equivilent_to_a_large_set_including_those_elements
    assert_false [1,2,3].equivalent?([1,2,3,4])
  end

  def test_should_be_equivalent_if_there_are_duplicate_values_in_one_of_the_arrays
    assert_false [2,3].equivalent?([3,2,2])
    assert_false [2,3,3].equivalent?([3,2])
  end

  def test_should_know_it_is_equivalent_if_in_the_same_order
    assert [1,2,3].equivalent?([1,2,3])
  end

  def test_should_be_equivalent_if_there_are_duplicate_values
    assert [2,2,3].equivalent?([3,2,2])
  end

  def test_should_know_it_is_equivalent_if_the_order_differs
    assert [1,2,3].equivalent?([2,1,3])
  end

  def test_should_produce_successive_groups_of_things
    assert_equal [[1], [2], [3], [4], [5]], (1..5).to_a.groups_of(1)
    assert_equal [[1,2], [2,3], [3,4], [4,5]], (1..5).to_a.groups_of(2)
    assert_equal [[1,2,3], [2,3,4], [3,4,5]], (1..5).to_a.groups_of(3)
    assert_equal [[1,2,3,4], [2,3,4,5]], (1..5).to_a.groups_of(4)
    assert_equal [[1,2,3,4,5]], (1..5).to_a.groups_of(5)
  end

  def test_should_yield_successive_chunks
    expected = [[1,2,3], [2,3,4], [3,4,5]]
    result = (1..5).to_a.groups_of(3) { |chunk| expected.delete(chunk); false }
    assert expected.empty?
    assert result.empty?
  end

  def test_bold_should_bold_individual_elements
    assert_equal ['a'.bold, 'b'.bold, 'c'.bold], ['a', 'b', 'c'].bold
  end

  def test_second_should_return_the_second_element_or_nil_if_none_is_present
    assert_equal 2, [1, 2, 3].second
    assert_equal nil, [1].second
  end

  def test_join_with_prefix
    assert_equal '', [].join_with_prefix(', ')
    assert_equal ', a, b', ['a', 'b'].join_with_prefix(', ')
  end

  def test_sort_with_nil_by
    assert_equal [nil, 'hello'], ['hello', nil].sort_with_nil_by{|e| e }
    assert_equal [nil, nil], [nil, nil].sort_with_nil_by{|e| e }
    assert_equal [nil, 'hello', 'world'], ['world', 'hello', nil].sort_with_nil_by{|e| e }
  end

  def test_extract_will_return_values_rejected
    array = [1, 2, 3, 4, 6]
    assert_equal [1, 2, 3], array.extract!{ |i| i < 4 }
    assert_equal [4, 6], array
  end

  def test_plural_will_pluralize_each_word_if_multiple_items_exist
    assert_equal 'this file', %w{this file}.plural(1)
  end

  def test_plural_will_keep_words_singular_if_only_one_item_exists
    assert_equal 'these files', %w{this file}.plural(2)
  end

  def test_sequence_pairs
    original = %w{a b c}
    assert_equal [['a', 'b'], ['b', 'c']], original.sequence_pairs
    assert_equal %w{a b c}, original
    assert_equal [], [].sequence_pairs
    assert_equal [], ['a'].sequence_pairs
  end

  def test_sequence_pairs_with_nil_in_original
    assert_equal [[nil, 'a'], ['a', nil]], [nil, 'a', nil].sequence_pairs
  end

  def test_shift_each_should_pop_each_element_out
    array = [1, 2, 3]
    popped = []
    array.shift_each! { |e| popped << e }
    assert_equal [], array
    assert_equal [1, 2, 3], popped
  end

  def test_shift_each_with_breaks_works
    array = [1, 2, 3]
    ret = array.shift_each! { |e| break if e == 2 }
    assert_nil ret

    array = [1, 2, 3]
    ret = array.shift_each! { |e| break(e) if e == 2 }
    assert_equal 2, ret
    assert_equal [3], array
  end

end
