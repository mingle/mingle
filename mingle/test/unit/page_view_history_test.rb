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

class PageViewHistoryTest < ActiveSupport::TestCase
  
  def test_should_initialize_if_not_already_initialized
    view_history = PageViewHistory.new
    assert_equal nil, view_history.current_page('project1')
    assert_equal [], view_history.recent_pages('project1')
    assert_equal ['page1'], view_history.add('project1', 'page1')
    assert_equal({'project1' => ['page1']}, view_history.to_hash)
  end
  
  def test_should_add_to_first_element_when_viewing_page
    view_history = PageViewHistory.new('project1' => ['page1', 'page2'])
    assert_equal ['page3', 'page1', 'page2'], view_history.add('project1', 'page3')
  end
  
  def test_should_not_allow_duplicates_when_viewing_the_same_page_again
    view_history = PageViewHistory.new('project1' => ['page1', 'page2'])
    view_history.add('project1', 'page1')
    assert_equal 'page1', view_history.current_page('project1')
    assert_equal ['page1', 'page2'], view_history.recent_pages('project1')
    
    view_history = PageViewHistory.new('project1' => ['page1', 'page2'])
    view_history.add('project1', 'page2')
    assert_equal 'page2', view_history.current_page('project1')
    assert_equal ['page1', 'page2'], view_history.recent_pages('project1')
    
    view_history = PageViewHistory.new('project1' => ['page1', 'page2', 'page3'])
    view_history.add('project1', 'page3')
    assert_equal 'page3', view_history.current_page('project1')
    assert_equal ['page1', 'page2', 'page3'], view_history.recent_pages('project1')
    
    view_history = PageViewHistory.new('project1' => ['page2', 'page3', 'page2', 'page1'])
    view_history.add('project1', 'page2')
    assert_equal 'page2', view_history.current_page('project1')
    assert_equal ['page2', 'page3', 'page1'], view_history.recent_pages('project1')
  end
  
  def test_should_not_allow_duplicates_when_viewing_a_page_that_has_already_been_seen
    view_history = PageViewHistory.new('project1' => ['page1', 'page2'])
    view_history.add('project1', 'page2')
    assert_equal 'page2', view_history.current_page('project1')
    assert_equal ['page1', 'page2'], view_history.recent_pages('project1')
  end
  
  def test_should_not_store_more_than_6_pages_of_history
    view_history = PageViewHistory.new('project1' => ['page1', 'page2', 'page3', 'page4', 'page5', 'page6'])
    view_history.add('project1', 'page7')
    assert_equal 'page7', view_history.current_page('project1')
    assert_equal ['page1', 'page2', 'page3', 'page4', 'page5'], view_history.recent_pages('project1')
  end
  
end
