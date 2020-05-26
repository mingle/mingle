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

class PaginationSupportTest < ActiveSupport::TestCase
  include PaginationSupport
  attr_accessor :paginator
  
  def test_should_render_all_pages_when_pages_are_less_than_limitation
    @paginator = create_paginator(1)
    assert_equal [1], self.available_pages
    
    @paginator = create_paginator(11)
    assert_equal (1..11).to_a, self.available_pages
    
    @paginator = create_paginator(50)
    @paginator.current_page = 25
    assert_equal [1, 2, 22, 23, 24, 25, 26, 27, 28, 49, 50], self.available_pages
    
    @paginator = create_paginator(12)
    @paginator.current_page = 1
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12], self.available_pages
        
    @paginator = create_paginator(12)
    @paginator.current_page = 12
    assert_equal [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12], self.available_pages
    
    @paginator = create_paginator(13)
    @paginator.current_page = 7
    assert_equal [1, 2, 4, 5, 6, 7, 8, 9, 10, 12, 13], self.available_pages
    
    (1..6).each do |current_page|
      @paginator = create_paginator(13)
      @paginator.current_page = current_page
      assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13], self.available_pages
    end
  end
 
  private
  def create_paginator(page_count)
    perpage = 5
    @paginator = Paginator.new(perpage * page_count , perpage)
  end
end
