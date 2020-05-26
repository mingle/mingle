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

# Includers must define to_params and an attribute called paginator
# to include this module. Then the includer becomes a paged object and can display
# its page links using the shared/page_links partial.
module PaginationSupport
  
  PAGE_WINDOW_SIZE = 7
  
  def multipage?
    defined?(paginator) ? paginator.page_count > 1 : false
  end  
 
  def previous_page
    paginator.previous
  end

  def next_page
    paginator.next
  end  

  def pages
    (1..paginator.page_count).to_a
  end  
 
  def current_page?(page)
    paginator.current_page.to_i == page.to_i
  end  
 
  def current_page
    paginator.current_page.to_i
  end
 
  def available_pages(page_window_size=PAGE_WINDOW_SIZE)
    (start_and_end_pages + current_page_neighbours(page_window_size)).uniq.sort
  end 
  
  def pre_page_options
    to_params.merge(:page => previous_page.to_i)
  end
  
  def next_page_options
    to_params.merge(:page => next_page.to_i)
  end
  
  def current_page_neighbours(page_window_size)
    neighbours = pages - start_and_end_pages
    neighbours.sort_by{|page| (page - current_page).abs }[0..page_window_size - 1]
  end
    
  def start_and_end_pages
    pages.length < 5 ? pages : pages[0..1] + pages[-2..-1]
  end
  
  def first_item_in_current_page
    paginator.current_page_first_item
  end
  
  def last_item_in_current_page
    paginator.current_page_last_item
  end
end  
