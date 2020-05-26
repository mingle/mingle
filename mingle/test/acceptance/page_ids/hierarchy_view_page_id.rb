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

module HierarchyViewPageId

  HIERARCHY_VIEW_LINK = 'link=Hierarchy'

  def card_id_on_hierarchy_view(card)
    css_locator("a[name='card_name_link_#{card}']")
  end

  def twisty_id_for_card(card)
    "twisty_for_card_#{card}"
  end

  def node_card_id(card)
    "node_#{card.html_id}"
  end
end
