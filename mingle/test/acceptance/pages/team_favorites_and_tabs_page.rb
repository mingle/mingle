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

module TeamFavoritesAndTabsPage
  def assert_link_direct_user_to_favorite_management_page(message_type)
    target_url = @browser.get_element_attribute("css=div.#{message_type} li a", 'href')
    @browser.open target_url
    @browser.assert_title "#{@project.name} Favorites - Mingle"
  end

  def assert_tabs_present_on_management_page(*tab_name_defs)
    tab_name_defs.each {|tab_name_def| @browser.assert_element_present(remove_from_tab_page(tab_name_def))}
  end

  def assert_tabs_not_present_on_management_page(*tab_name_defs)
    tab_name_defs.each {|tab_name_def| @browser.assert_element_not_present(remove_from_tab_page(tab_name_def))}
  end

  def assert_card_favorites_present_on_management_page(project, *favorites_name_defs)
    favorites_name_defs.each do |favorites_name_def|
      favorites_name_def = project.card_list_views.find_by_name(favorites_name_def) unless favorites_name_def.respond_to?(:name)
      if @browser.is_element_present(move_to_tab_page(favorites_name_def))
        @browser.assert_element_present(move_to_tab_page(favorites_name_def))
      else
        @browser.assert_element_present(move_to_tab_cardlistview(favorites_name_def))
      end
    end
  end

  def assert_favorites_not_present_on_management_page(project, *favorites_name_defs)
    favorites_name_defs.each do |favorites_name_def|
      favorites_name_def = project.card_list_views.find_by_name(favorites_name_def) unless favorites_name_def.respond_to?(:name)
      @browser.assert_element_not_present(move_to_tab_page(favorites_name_def))
      @browser.assert_element_not_present(move_to_tab_cardlistview(favorites_name_def))
    end
  end

  def assert_favorites_not_editable(*favorites_name_defs)
    favorites_name_defs.each{|favorites_name_def| @browser.assert_element_not_present(move_to_tab_page(favorites_name_def))}
  end

  def assert_tabs_not_editable(*tab_name_defs)
    tab_name_defs.each {|tab_name_def| @browser.assert_element_not_present(remove_from_tab_page(tab_name_def))}
  end
end
