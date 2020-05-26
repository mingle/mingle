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

module TeamFavoritesAndTabsAction
  
  def navigate_to_favorites_management_page_for(project)
     project = project.identifier if project.respond_to? :identifier
     @browser.open "/projects/#{project}/favorites/list"
   end
   
   def toggle_tab_for_view_named(view_name)
     view = Project.current.reload.card_list_views.find_by_name(view_name)
     toggle_tab_for_saved_view(view)
   end

   def toggle_tab_for_saved_view(*saved_views)
     saved_views.each do |saved_view|
       if @browser.is_element_present move_to_tab_saved_view(saved_view)
         @browser.click_and_wait(move_to_tab_saved_view(saved_view))
       elsif @browser.is_element_present move_to_team_favorite_saved_view(saved_view)
         @browser.click_and_wait(move_to_team_favorite_saved_view(saved_view))
       else
         raise "Toggle tab for saved view #{saved_view.name} does not apply because the view is not a favorite or a tab."
       end
     end
   end
end
