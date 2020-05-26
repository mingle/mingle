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

module HierarchyViewPage

  def assert_card_present_in_hierarchy_view(card)
    @browser.assert_element_present(node_card_id(card))
    @browser.assert_element_matches(node_card_id(card), /#{card.name}/)
  end

  def assert_card_not_present_in_hierarchy_view(card)
    @browser.assert_element_not_present(node_card_id(card))
    @browser.assert_element_does_not_match(node_card_id(card), /#{card.name}/)
  end

  def assert_nodes_expanded_in_hierarchy_view(*cards)
    cards.each do |card|
      if (@browser.get_eval("this.browserbot.getCurrentWindow().$('twisty_for_card_#{card.number}').hasClassName('twisty expanded')") == 'true')
        true
      else
        raise "node is collapsed when expecting expanded"
      end
    end
  end

  def assert_nodes_collapsed_in_hierarchy_view(*cards)
    cards.each do |card|
      if (@browser.get_eval("this.browserbot.getCurrentWindow().$('twisty_for_card_#{card.number}').hasClassName('twisty collapsed')") == 'true')
        true
      else
        raise "node is expanded when expecting collapsed"
      end
    end
  end

end
