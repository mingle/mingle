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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class SmartSortTest < ActiveSupport::TestCase

  def test_smart_sort_by
    assert_equal [o('1'), o('2'), o('10'), o('orange')], 
      [o('10'),o('2'), o('1'), o('orange')].smart_sort_by{|m|m.name}
  end
  
  def test_sort_should_be_case_insensitive
    assert_equal %w(apple Banana orange), %w(Banana orange apple).smart_sort
  end
  
  def test_numeric_sort
    assert_equal [1,2,3,10], [3,2,10,1].smart_sort
    assert_equal %w(1 2 3 10), %w(3 2 10 1).smart_sort
  end

  def test_alphabetical_sort
    assert_equal %w(apple banana orange), %w(banana orange apple).smart_sort
  end

  def test_simple_mixed
    assert_equal %w(1 2 banana orange), %w(banana 2 1 orange).smart_sort
    assert_equal %w(1 2 10 orange), %w(10 2 1 orange).smart_sort
  end

  def test_simple_alphabetical_numer
    assert_equal ['1 iter', '2 iter', '11 iter', '20 iter'], ['2 iter', '20 iter', '1 iter', '11 iter'].smart_sort
    assert_equal ['iter 1', 'iter 2', 'iter 11', 'iter 20'], ['iter 2', 'iter 20', 'iter 1', 'iter 11'].smart_sort
    assert_equal %w(iter-1 iter-2 iter-11 iter-20), %w(iter-2 iter-20 iter-1 iter-11).smart_sort
  end

  def test_complex_mixed
    assert_equal ['2', '2 dogs'], ['2 dogs', '2'].smart_sort
    assert_equal ['2', '2 dogs', '10', '10 dogs','I have 2 apples', 'I have 10 apples'],
         ['2 dogs', 'I have 10 apples', '2','10', 'I have 2 apples', '10 dogs'].smart_sort
  end

  def test_numeric_split
    assert_equal ['iteration'], SmartSort.numeric_split('iteration').collect(&:str)
    assert_equal ['12'], SmartSort.numeric_split('12').collect(&:str) 
    assert_equal %w(iteration 1), SmartSort.numeric_split('iteration1').collect(&:str)
    assert_equal %w(iteration 10), SmartSort.numeric_split('iteration10').collect(&:str)
    assert_equal %w(10 iteration), SmartSort.numeric_split('10iteration').collect(&:str)
    assert_equal ['10', ' iteration'], SmartSort.numeric_split('10 iteration').collect(&:str) 
    assert_equal ['pick ', '10', ' up' ], SmartSort.numeric_split('pick 10 up').collect(&:str)
    assert_equal ['pick ', '10', ' upto ', '11' ], SmartSort.numeric_split('pick 10 upto 11').collect(&:str) 
  end

  private
  def o(name)
    OpenStruct.new(:name => name)
  end
end
