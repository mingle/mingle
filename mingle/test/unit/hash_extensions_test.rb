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

class HashExtensionsTest < ActiveSupport::TestCase

  def test_stringify_number_values_converts_floats_with_point_zero_to_integer_form
    assert_equal({ :a => "2" }, { :a => 2.00 }.stringify_number_values)
    assert_equal({ :a => "2" }, { :a => 2 }.stringify_number_values)
  end
  
  def test_stringify_number_values_leaves_non_numbers_alone
    some_date = Date.new
    assert_equal({ :a => some_date }, { :a => some_date }.stringify_number_values)
  end

  def test_find_by_numeric_key_get_maches_with_key_number_matching
    assert_equal 2, {"EA"=>2, "1.0"=>3}.find_by_numeric_key("EA")
    assert_equal 3, {"EA"=>2, "1.0"=>3}.find_by_numeric_key("1")
    assert_nil({"EA"=>2}.find_by_numeric_key('NO_EXIST'))
  end
  
  def test_find_by_zero
    assert_equal 10, {"0" => 10}.find_by_numeric_key("0")
    assert_equal 10, {"0" => 10}.find_by_numeric_key("0.0")
    assert_nil({"1" => 10}.find_by_numeric_key("0"))
  end
  
  #bug 5569, 5592
  def test_find_by_one
   assert_equal 10, {"1" => 10, "1.0" => 50}.find_by_numeric_key("1")
   assert_equal 50, {"1" => 10, "1.0" => 50}.find_by_numeric_key("1.0")
   assert_equal 10, {"1" => 10, "1.0" => 50}.find_by_numeric_key("1.00")
   assert_nil({"1" => 10}.find_by_numeric_key("0"))
  end

  #bug 5569
  def test_find_by_zero_with_non_numberic_keys
    assert_equal 10, {"EA" => 0, "0" => 10}.find_by_numeric_key("0.0")
    assert_nil({"EA" => 10}.find_by_numeric_key("0"))
  end
  
  def test_find_by_numeric_key_should_find_value_if_key_is_not_numeric
    assert_equal 1, { "key" => 1 }.find_by_numeric_key("key")
  end

  def test_find_by_numeric_key_should_convert_string_to_numeric
   hash = { 1 => 1 }
   assert_equal 1, hash.find_by_numeric_key("1.0")
   assert_equal 1, hash.find_by_numeric_key("1")
  end
  
  def test_filter_by_returns_original_hash_when_filtering_by_nil
    assert_equal({1 => "10", "a" => :rt, :e => 1}, {1 => "10", "a" => :rt, :e => 1}.filter_by(nil))
  end

  def test_filter_by_returns_original_hash_when_filtering_by_a_empty_hash
    assert_equal({1 => "10", "a" => :rt, :e => 1}, {1 => "10", "a" => :rt, :e => 1}.filter_by({}))
  end

  def test_filter_by_returns_original_hash_without_elements_present_in_another_hash
    assert_equal({1 => "10", :e => 1}, {1 => "10", "a" => :rt, :e => 1}.filter_by("a" => :rt))
    assert_equal({1 => "10"}, {1 => "10", "a" => :rt, :e => 1}.filter_by("a" => :rt, :e => 1))
    assert_equal({}, {1 => "10", "a" => :rt, :e => 1}.filter_by("a" => :rt, 1 => "10", :e => 1))
  end

  def test_filter_by_returns_an_empty_hash_when_filtered_by_a_hash_which_contains_more_entries_than_self
    assert_equal({}, {"a" => :rt}.filter_by(1 => "10", "a" => :rt, :e => 1))
  end

  def test_contains_returns_false_when_tested_against_a_hash_which_contains_more_entries_than_self
    assert_equal false, {"a" => :rt}.contains?(1 => "10", "a" => :rt, :e => 1)
  end

  def test_contains_returns_true_when_tested_against_a_hash_which_only_contains_elements_in_self
    assert_equal true, {1 => "10", "a" => :rt, :e => 1}.contains?("a" => :rt)
    assert_equal true, {1 => "10", "a" => :rt, :e => 1}.contains?("a" => :rt, :e => 1)
    assert_equal true, {1 => "10", "a" => :rt, :e => 1}.contains?("a" => :rt, 1 => "10", :e => 1)
  end

  def test_contains_returns_true_when_tested_against_nothing
    assert_equal true, {1 => "10", "a" => :rt, :e => 1}.contains?(nil)
  end

  def test_contains_returns_true_when_tested_against_an_empty_hash
    assert_equal true, {1 => "10", "a" => :rt, :e => 1}.contains?({})
  end

  def test_concatenative_match_combines_values_for_matching_keys_as_strings
    assert_equal({'a' => '1 2'}, {'a' => 1}.concatenative_merge('a' => '2'))
    assert_equal({'a' => '1 2', 'b' => 34}, {'a' => 1}.concatenative_merge('a' => '2', 'b' => 34))
  end
  
  def test_should_recursivly_joined_ordered_values_by_smart_sorted_keys
    assert_equal 'group_by={lane=status,row=size}', { :group_by => {:row => 'size', :lane => 'status' }  }.joined_ordered_values_by_smart_sorted_keys
    assert_equal 'group_by={lane=status,row=size}', { :group_by => { 'row' => 'size', :lane => 'status' }  }.joined_ordered_values_by_smart_sorted_keys
  end

  def test_joined_ordered_values_by_smart_sorted_keys_should_persist_boolean_values_
    assert_equal 'group_by={hide=true,lane=status}', { :group_by => {:hide => true, :lane => 'status' }  }.joined_ordered_values_by_smart_sorted_keys
    assert_equal 'group_by={hide=false,lane=status}', { :group_by => {:hide => false, :lane => 'status' }  }.joined_ordered_values_by_smart_sorted_keys
  end
  
end
