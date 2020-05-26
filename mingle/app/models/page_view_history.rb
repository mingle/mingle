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

class PageViewHistory
  
  MAX_PAGES = 5
  
  def initialize(viewed_pages={})
    @viewed_pages = viewed_pages
  end
  
  def add(project_id, page_id)
    pages = all_pages(project_id)
    pages.uniq!
    pages.insert(0, page_id)
    @viewed_pages[project_id] = pages[0..MAX_PAGES]
  end
  
  def current_page(project_id)
    all_pages(project_id).first
  end
  
  def recent_pages(project_id)
    all_pages(project_id)[1..MAX_PAGES] || []
  end
  
  def to_hash
    @viewed_pages.stringify_keys
  end
  
  private
  
  def all_pages(project_id)
    @viewed_pages[project_id.to_s] || []
  end
end
