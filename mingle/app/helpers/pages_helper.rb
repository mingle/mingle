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

module PagesHelper
  include FeedHelper
  
  def is_a_team_favorite_or_tab(page)
    favorite = @project.favorites_and_tabs.of_pages.of_team.find_by_favorited_id(page.id)
    return favorite ? favorite.favorite? : false
  end
  
  def is_a_tab(page)
    !!@project.tabs.of_pages.of_team.find_by_favorited_id(page.id)
  end
  
  # we used to name this method 'can_mark_as_favorite',
  # which is wrong, becuase the code calling this method could remove the page favorite
  # and, actually this method should always return true when current user is a project admin,
  # which is confirmed as a bug.
  # So, we change the method name as where uses it for now.
  # Who else trys to fix the bug, should make this method cleanup.
  def admin_user_or_not_a_tab?
    return true if User.current.admin?
    return true if Project.current.admin?(User.current)
    !@project.tabs.of_pages.of_team.find_by_favorited_id(@page.id)
  end

  def tab_title
    is_a_tab(@page) ? 'Remove tab' : 'Make tab'
  end
  
  def favorite_title
    is_a_team_favorite_or_tab(@page) ? 'Remove team favorite' : 'Make team favorite'
  end

  def personal_page?(page)
    return false if page.nil?
    !!@project.favorites.of_pages.personal(User.current).find_by_favorited_id(page.id)
  end

  def authorized_to_delete_attachments
    authorized_for?(@project, :controller => 'pages', :action => 'remove_attachment')
  end
end
