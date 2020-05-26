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

class Paginator

  attr_reader :current_page, :item_count, :items_per_page

  class << self
    def create_with_current_page(item_count, options = {})
      current_page = current_page.to_i
      per_page = options[:items_per_page].blank? ? PAGINATION_PER_PAGE_SIZE : options[:items_per_page].to_i

      paginator = Paginator.new(item_count, per_page)
      paginator.current_page = (1..paginator.page_count).find_closest((options[:page] || 1).to_i)
      paginator
    end
  end

  def initialize(item_count, items_per_page, the_current_page = 1)
    @item_count = item_count
    @items_per_page = items_per_page
    self.current_page = the_current_page
  end

  def current_page=(current_page)
    @current_page = valid_page?(current_page) ? current_page : 1
  end

  def page_count
    @page_count ||= @item_count.zero? ? 1 : compute_page_count
  end

  def next
    @current_page == page_count ? nil : @current_page + 1
  end

  def previous
    @current_page == 1 ? nil : @current_page - 1
  end

  def current_page_offset
    @items_per_page * (@current_page - 1)
  end

  def current_page_first_item
    current_page_offset + 1
  end

  def current_page_last_item
    [@items_per_page * @current_page, @item_count].min
  end

  def limit_and_offset
    {:limit => @items_per_page, :offset => current_page_offset}
  end

  private

  def valid_page?(current_page)
    current_page >= 1 && current_page <= page_count
  end

  def compute_page_count
    whole_pages, remaining_items = @item_count.divmod(@items_per_page)
    remaining_items == 0 ? whole_pages : whole_pages + 1
  end
end
