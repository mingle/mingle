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

class PaginatorTest < ActiveSupport::TestCase
  
  def test_setting_page_to_something_invalid_should_set_page_to_one
    item_count = 100
    items_per_page = 10
    
    paginator = Paginator.new(item_count, items_per_page)
    paginator.current_page = 11
    assert_equal 1, paginator.current_page
    
    paginator.current_page = 0
    assert_equal 1, paginator.current_page
    
    paginator = Paginator.new(item_count, items_per_page, 0)
    assert_equal 1, paginator.current_page
    
    paginator = Paginator.new(item_count, items_per_page, 11)
    assert_equal 1, paginator.current_page
  end
  
  def test_page_count
    assert_equal 3, Paginator.new(30, 10).page_count
    assert_equal 4, Paginator.new(32, 10).page_count
    assert_equal 1, Paginator.new(2, 2).page_count
    assert_equal 1, Paginator.new(0, 2).page_count
  end
  
  def test_first_item_and_last_item_of_page
    paginator = Paginator.new(34, 10)
    
    paginator.current_page = 2
    assert_equal 11, paginator.current_page_first_item
    assert_equal 20, paginator.current_page_last_item 
    
    paginator.current_page = 4
    assert_equal 31, paginator.current_page_first_item
    assert_equal 34, paginator.current_page_last_item 
  end
  
  def test_current_page_offset
    paginator = Paginator.new(34, 10)
    
    paginator.current_page = 2
    assert_equal 10, paginator.current_page_offset
    
    paginator.current_page = 4
    assert_equal 30, paginator.current_page_offset
  end
  
  def test_first_page_should_not_have_a_previous_page
    paginator = Paginator.new(100, 10, 1)
    assert_equal(1, paginator.current_page)
    assert !paginator.previous
  end
  
  def test_should_have_previous_page_if_not_on_first_page
    paginator = Paginator.new(100, 10, 2)
    assert_equal(2, paginator.current_page)
    assert_equal(1, paginator.previous)
  end
  
  def test_last_page_should_not_have_a_next_page
    paginator = Paginator.new(100, 10, 10)
    assert_equal(10, paginator.current_page)
    assert !paginator.next
  end
  
  def test_should_have_next_page_if_not_on_last_page
    paginator = Paginator.new(100, 10, 9)
    assert_equal(9, paginator.current_page)
    assert_equal(10, paginator.next)
  end
  
  def test_single_page_should_not_have_previous_page
    paginator = Paginator.new(10, 25)
    assert !paginator.previous
    assert !paginator.next
  end
end
