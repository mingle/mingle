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

module HierarchyViewAction


    def switch_to_hierarchy_view
      if @browser.is_element_present(HierarchyViewPageId::HIERARCHY_VIEW_LINK)
        @browser.click_and_wait HierarchyViewPageId::HIERARCHY_VIEW_LINK
      end
    end

    def click_card_on_hierarchy_list(card)
        # card = card.number if card.respond_to? :number
         @browser.get_eval "this.browserbot.getCurrentWindow().$('node_#{card.html_id}').click()"
         @browser.wait_for_page_to_load
        # @browser.click_and_wait card_id_on_hierarchy_view(card)
    end

    def navigate_to_hierarchy_view_for(project, tree)
        @browser.open("/projects/#{project.identifier}/cards/hierarchy?tree_name=#{tree.name}")
    end

    def click_twisty_for(*cards)
        cards.each do |card|
            card = card.number if card.respond_to? :number
            @browser.with_ajax_wait do
                @browser.click(twisty_id_for_card(card))
            end
            @browser.wait_for_all_ajax_finished
        end
    end
end
