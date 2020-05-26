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

module  SearchResultsAction
  
  def click_card_link_on_search_result(card)
      @browser.click_and_wait(card_link_on_result_on_search_page(card))
  end
  
  def navigate_to_search_tab(tabname)
    @browser.click_and_wait(search_tab(tabname))
  end
  
  def click_to_view_murmur(creatorname)
    @browser.click_and_wait link_to_view_murmurs(creatorname)
  end

end
