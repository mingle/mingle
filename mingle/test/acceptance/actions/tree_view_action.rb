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

module TreeViewAction

    def navigate_to_tree_view_for(project, tree_name, expands=nil)
        if expands.nil?
            expands = project.find_tree_configuration(tree_name).tree_belongings.collect(&:card).collect(&:number)
        end
        @browser.open("/projects/#{project.identifier}/cards/tree?tree_name=#{tree_name}&expands=#{expands.join(',')}")
        wait_for_tree_result_load
    end

    def switch_to_tree_view
      if @browser.is_element_present(TreeViewPageId::TREE_LINK)
        @browser.click_and_wait TreeViewPageId::TREE_LINK
      end
    end

    def wait_for_tree_result_load
        @browser.wait_for_all_ajax_finished
        @browser.wait_for_element_present('tree') unless @browser.is_element_present(TreeViewPageId::TREE_LINK)
        @browser.wait_for_element_not_visible(TreeViewPageId::TREE_RESULTS_SPINNER_ID) if @browser.is_element_present(TreeViewPageId::TREE_RESULTS_SPINNER_ID)
    end

    def confirm_box_visible?
        @browser.is_visible(TreeViewPageId::CONFIRM_BOX_ID)
    end

    def remove_card_and_its_children_from_tree_for(project, tree_name, card, options = {})
        after_clicking_on_remove_node_link_for(project, tree_name, card, options) { click_remove_this_card_and_its_children }
    end

    def remove_card_without_its_children_from_tree_for(project, tree_name, card, options = {})
        after_clicking_on_remove_node_link_for(project, tree_name, card, options) { click_remove_just_this_card }
    end

    def click_remove_just_this_card
        @browser.with_ajax_wait do
            @browser.click(TreeViewPageId::REMOVE_JUST_THIS_CARD_XPATH)
        end
    end

    def click_remove_this_card_and_its_children
        @browser.with_ajax_wait do
            @browser.click(TreeViewPageId::REMOVE_THIS_CARD_AND_ITS_CHILDREN_XPATH)
        end
    end

    def after_clicking_on_remove_node_link_for(project, tree_name, card, options={}, &block)
        navigate_to_tree_view_for(project, tree_name) unless options[:already_on_tree_view]
        click_remove_card_from_tree(card, tree_name)
        if remove_will_bring_confirm_box?(card, tree_name)
            yield
            wait_till_remove_action_is_complete(card)
        end
    end

    def click_remove_card_from_tree(card, tree_configuration)
        if remove_will_bring_confirm_box?(card, tree_configuration)
            @browser.click(node_card_remove_link(card))
            @browser.wait_for_element_visible(TreeViewPageId::CONFIRM_BOX_ID)
        else
            @browser.with_ajax_wait do
                @browser.click(node_card_remove_link(card))
            end
        end
    end

    def click_cancel_remove_from_tree
        @browser.with_ajax_wait do
            @browser.click(TreeViewPageId::CANCEL_XPATH)
        end
    end

    def wait_till_remove_action_is_complete(card)
        #When the remove action is complete, it re-enaables all links on the view
        #This means that there will be no more ghostly overlay; which goes by the id of doc_overlay
        @browser.wait_for_element_not_visible(TreeViewPageId::DOC_OVERLAY_ID)
    end


    def switch_to_tree_view
        @browser.click_and_wait TreeViewPageId::TREE_LINK
    end

    def click_configure_current_tree_link
        @browser.click(TreeViewPageId::TREE_CONFIGURE_WIDGET_BUTTON)
        @browser.click_and_wait(TreeViewPageId::CONFIGURE_LINK)
    end

    def select_tree(tree_name)
        tree_name = tree_name.name if tree_name.respond_to?(:name)
        @browser.click(TreeViewPageId::WORKSPACE_SELECTOR_LINK)
        @browser.wait_for_element_visible(TreeViewPageId::WORKSPACE_SELECTOR_PANEL_ID)
        if (tree_name || '').downcase == 'none'
            @browser.click_and_wait(TreeViewPageId::TREE_NONE_SELECT_ID)
        else
            tree = Project.current.tree_configurations.find_by_name(tree_name)
            @browser.click_and_wait(tree_selector_id(tree))
            wait_for_tree_result_load
        end
    end

    # quick add cards helper for tree view
    def switch_to_tree_view_through_action_bar
        @browser.click_and_wait(TreeViewPageId::TREE_LINK)
        wait_for_tree_result_load
        assert_equal "Tree", @browser.get_text("css=.selected_view")
    end

    def click_on_quick_add_cards_to_tree_link_for(card)
        if (card.to_s == 'root')
            @browser.with_ajax_wait do
                @browser.click(TreeViewPageId::NODE_ADD_NEW_CARDS_ID)
            end
            @browser.wait_for_element_present(TreeViewPageId::TREE_CARDS_QUICK_ADD_FORM)
        elsif (@browser.is_element_present(card_inner_element(card)))
            @browser.with_ajax_wait do
                @browser.click(node_add_new_cards(card))
            end
            @browser.wait_for_element_present(TreeViewPageId::TREE_CARDS_QUICK_ADD_FORM)
        else
            raise "card #{card} is not present on tree..."
        end
    end

    def quick_add_cards_on_tree(project, tree, card, options={})
        location = @browser.get_location
        card_names = options[:card_names]
        card_type = options[:type] || nil
        reset_filter = options[:reset_filter] || 'yes'
        navigate_to_tree_view_for(project, tree.name) if (reset_filter == 'yes')
        click_on_quick_add_cards_to_tree_link_for(card)
        select_type_for_quick_add_on_tree(card_type) if card_type != nil
        card_names.each_with_index do |card_name, index|
            if(index <= 4)
                type_card_name_on_quick_add(index, card_name)
            else
                add_new_line_in_quick_add
                type_card_name_on_quick_add(index, card_name)
            end
        end
        @browser.with_ajax_wait do
            @browser.click(TreeViewPageId::TREE_CARDS_QUICK_ADD_SAVE_BUTTON)
        end
    end

    def quick_add_cards_to_tree_on_card_show(project, tree, options={})
        card_names = options[:card_names]
        card_type = options[:type] || nil
        click_on_create_children_for(tree)
        select_type_for_quick_add_on_tree(card_type) if card_type != nil
        card_names.each_with_index do |card_name, index|
            if(index <= 4)
                type_card_name_on_quick_add(index, card_name)
            else
                add_new_line_in_quick_add
                type_card_name_on_quick_add(index, card_name)
            end
        end
        @browser.with_ajax_wait do
            @browser.click(TreeViewPageId::TREE_CARDS_QUICK_ADD_SAVE_BUTTON)
        end
    end

    def delete_line_from_quick_add(line_number)
        @browser.click(class_locator(TreeViewPageId::REMOVE_BUTTON_CLASS_LOCATOR, line_number))
    end

    def add_new_line_in_quick_add
        @browser.click(class_locator(TreeViewPageId::ADD_BUTTON_CLASS_LOCATOR, 0))
    end

    def type_card_name_on_quick_add(line_number, card_name)
        @browser.type(class_locator(TreeViewPageId::CARD_NAME_CLASS_LOCATOR, line_number), card_name)
    end

    def select_type_for_quick_add_on_tree(type_name)
        if(@browser.is_element_present(TreeViewPageId::TREE_CARDS_QUICK_ADD_FORM))
            @browser.click(TreeViewPageId::CARD_TYPE_SELECT_DROPDOWN)
            @browser.click(quick_add_card_type_option(type_name))
        else
            raise "quick add popup not available..."
        end
    end

    def click_tree_cards_quick_add_cancel_button
        @browser.click(TreeViewPageId::TREE_CARD_QUICK_ADD_CANCEL_BUTTON)
    end

    def click_on_card_in_tree(card)
      locator = "card_popup_outer_#{card.number}"
      @browser.wait_for_element_present(card_inner_element(card))
      @browser.click(card_inner_element(card))
      @browser.wait_for_element_present(locator)
      @browser.wait_for_element_visible(locator)
    end

    def click_on_transition_for_card_in_tree_view(card, transition)
        click_on_card_in_tree(card)
        @browser.with_ajax_wait do
            @browser.click(transition_id(transition))
        end
    end

    def open_a_card_in_tree_view(project, card_number)
        open_a_card_in_grid_view(project, card_number)
    end

    def navigate_to_list_view_of_tree(project,tree_name)
        navigate_to_tree_view_for(project, tree_name.name)
        @browser.click_and_wait TreeViewPageId::LIST_LINK
    end

    def drag_and_drop_card_in_tree(card_to_be_dropped, card_to_be_dragged)
        assert_card_showing_on_tree(card_to_be_dropped) unless card_to_be_dropped.respond_to?(:root?) && card_to_be_dropped.root?
        assert_card_showing_on_tree(card_to_be_dragged)
        @browser.eval_javascript("TreeView.tree.dragAndDropCardInTreeForSelenium('#{card_to_be_dropped.number}','#{card_to_be_dragged.number}')")
        @browser.wait_for_all_ajax_finished
    end

    def click_remove_link_for_card(card)
        @browser.with_ajax_wait do
            @browser.click(node_card_remove_link(card))
        end
    end

    def expand_collapse_nodes_in_tree_view(*cards)
        cards.each do |card|
            @browser.with_ajax_wait do
                @browser.click(twisty_between_nodes_in_cards(card))
            end
            # @browser.wait_for_all_ajax_finished
        end
    end

    def search_in_tree_incremental_search_input(search_string, expected_result)
        @browser.type(TreeViewPageId::TREE_INCREMENTAL_SEARCH_INPUT, search_string)
        @browser.key_down(TreeViewPageId::TREE_INCREMENTAL_SEARCH_INPUT, search_string)
        @browser.key_up(TreeViewPageId::TREE_INCREMENTAL_SEARCH_INPUT, search_string)
        @browser.assert_text_present(expected_result)
    end


    private

    def remove_will_bring_confirm_box?(card, tree_configuration)
        tree_configuration = Project.current.tree_configurations.detect { |tc| tc.name == tree_configuration } unless tree_configuration.respond_to?(:name)
        card.has_children?(tree_configuration)
    end
end
