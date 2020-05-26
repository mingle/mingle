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

module TreeViewPage

  def assert_card_in_tree(project, tree, card)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    tree = project.tree_configurations.find_by_name(tree) unless tree.respond_to?(:name)
    assert(tree.include_card?(card))
  end

  def assert_card_not_in_tree(project, tree, card)
    project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
    tree = project.tree_configurations.find_by_name(tree) unless tree.respond_to?(:name)
    assert(! tree.include_card?(card))
  end

  def assert_cards_on_a_tree(project, *cards)
    project = project.identifier if project.respond_to? :identifier
    cards.each do |card|
      card = Project.find_by_identifier(project).cards.find_by_name(card) unless card.respond_to?(:name)
      @browser.assert_element_present(card.html_id)
    end
  end

  def assert_card_not_present_on_tree(project, *cards)
    cards.each{ |card| @browser.assert_element_not_present(tree_card_locator(card)) }
  end

  def tree_card_locator(card)
    css_locator "#tree ##{card.html_id}"
  end

  def assert_card_showing_on_tree(card)
    @browser.assert_element_present(card_on_tree_id(card))
  end

  def assert_cards_showing_on_tree(*cards)
    cards.each { |card| assert_card_showing_on_tree(card) }
  end

  def assert_card_not_showing_on_tree(card)
    @browser.assert_element_not_present(card_on_tree_id(card))
  end

  def assert_cards_not_showing_on_tree(*cards)
    cards.each { |card| assert_card_not_showing_on_tree(card) }
  end

  def assert_drop_card_here_bubble_is_showing
    @browser.assert_visible(TreeViewPageId::DROP_CARD_HERE_BUBBLE_ID)
  end

  def assert_drop_card_here_bubble_is_not_showing
    @browser.assert_not_visible(TreeViewPageId::DROP_CARD_HERE_BUBBLE_ID)
  end

  def assert_no_cards_assigned_message(tree)
    @browser.assert_text_present("No cards that have been assigned to #{tree.name} tree match the current filter - Reset filter")
  end

  def assert_tree_not_present_on_management_page(tree_name)
    @browser.assert_element_does_not_match('content', /#{tree_name}/)
  end

  # tree Configuration related assertions
  def assert_selected_tree_type(type_node_number, type_name)
    @browser.assert_text class_locator('select-type', type_node_number), type_name
  end

  def assert_tree_configuration_nodes_hierarchy(*type_nodes)
    type_nodes.each_with_index do |type_node, index|
      assert_selected_tree_type(index, type_node)
    end
  end

  def assert_edit_relationship_link_visible(options)
    @browser.assert_visible("edit_relationship_#{options[:type_node_number]}_link")
  end

  def assert_card_types_in_drop_down_list_on_a_tree_node(card_type_node, *types)
    click_select_type_link_for(card_type_node)
    types.each do |type|
      @browser.assert_element_present(card_type_node_option_id(card_type_node,type))
    end
    click_select_type_link_for(card_type_node, :click_to_open => false)
  end

  def assert_card_types_not_present_in_drop_down_on_a_tree_node(card_type_node, *types)
    click_select_type_link_for(card_type_node)
    types.each do |type|
      @browser.assert_element_not_present(card_type_node_option_id(card_type_node,type))
    end
    click_select_type_link_for(card_type_node, :click_to_open => false)
  end

  def assert_remove_tree_node_not_present_for_a_card_type_nodes
    (0..1).each do |node_number|
      @browser.assert_not_visible class_locator('remove-button', node_number)
    end
  end

  def assert_remove_tree_node_present_for_a_card_type_nodes(number_of_nodes) # specify number of nodes need to be checked. Ex:if 2 specifed means 0,1,2 -nodes
    (0..number_of_nodes).each do |node_number|
      @browser.assert_visible class_locator('remove-button', node_number)
    end
  end

  def assert_can_create_new_card_tree(project)
    assert_link_present("/projects/#{project.identifier}/card_trees/new")
  end

  def assert_can_edit_a_tree_configuration(project, tree_name)
    card_tree_def = project.tree_configurations.find_by_name(tree_name)
    assert_link_present("/projects/#{project.identifier}/card_trees/edit/#{card_tree_def.id}")
  end

  def assert_cannot_create_new_tree(project)
    assert_link_not_present("/projects/#{project.identifier}/card_trees/new")
  end

  def assert_cannot_edit_a_tree_configuration(project, tree_name)
    card_tree_def =  project.tree_configurations.find_by_name(tree_name)
    assert_link_not_present("/projects/#{project.identifier}/card_trees/edit/#{card_tree_def.id}")
  end

  def assert_links_view_hirarchy_and_configure_tree_present_for(project, tree_def)
    @browser.assert_element_present("//a[contains(@href, '/projects/#{project.identifier}/card_trees/edit/#{tree_def.id}')]")
    @browser.assert_element_present("//a[contains(@href, '/projects/#{project.identifier}/cards/tree?tree_name=#{tree_def.name.to_s.gsub(/[' ']/, '+')}')]")
    @browser.assert_element_present("//a[contains(@href, '/projects/#{project.identifier}/cards/hierarchy?tree_name=#{tree_def.name.to_s.gsub(/[' ']/, '+')}')]")
  end

  def assert_first_level_node(card)
    assert_card_showing_on_tree(card)
    @browser.assert_element_present css_locator("div.vtree-column > div##{card.html_id}")
  end

  def assert_parent_node(expect_parent, card)
    assert_card_showing_on_tree(card)
    assert_card_showing_on_tree(expect_parent)
    @browser.assert_element_present css_locator("div##{expect_parent.html_id} > div.sub-tree > div##{card.html_id}")
  end

  def assert_candidate_card_is_draggable_in_search(card)
    candidate_id = search_child_card_candidate_id(card)
    @browser.assert_element_present(candidate_id)
    @browser.eval_javascript("$('#{candidate_id}').hasClassName('card-child-candidate')")
    assert @browser.eval_javascript("TreeView.draggableFor('#{candidate_id}')!=null")
  end

  def assert_candidate_card_is_not_draggable_in_search(card)
   candidate_id = search_child_card_candidate_id(card)
    @browser.assert_element_present(candidate_id)
    @browser.eval_javascript("$('#{candidate_id}').hasClassName('card-child-disabled')")
    assert @browser.eval_javascript("TreeView.draggableFor('#{candidate_id}')==null")
  end

   def assert_current_tree_configuration_on_tree_view_page(*types)
     types.each_with_index do |type, i|
       actual_type = @browser.get_eval("this.browserbot.getCurrentWindow().$('tree-configure-overview').select('.type-node')[#{i}].innerHTML.unescapeHTML().strip()")
       assert_equal(actual_type, type)
     end
   end

   def assert_link_configure_tree_on_current_tree_configuration_widget
     @browser.click(TreeViewPageId::TREE_CONFIGURE_WIDGET_BUTTON)
     @browser.assert_element_present(TreeViewPageId::CONFIGURE_LINK_ID)
   end

   def assert_link_configure_tree_not_present_on_current_tree_configuration_widget
     @browser.click(TreeViewPageId::TREE_CONFIGURE_WIDGET_BUTTON)
     @browser.assert_element_not_present(TreeViewPageId::CONFIGURE_LINK_ID)
   end

   def assert_current_tree_on_view(tree_name)
     assert_root_node_has_tree_name(tree_name)
   end

   # this will of course only work if no other cards have the same name as the tree
   def assert_root_node_has_tree_name(tree_name)
     assert_equal(tree_name, @browser.get_eval("#{class_locator('card-name')}.innerHTML.strip()"))
   end

   def assert_tree_selected(tree_name)
     @browser.assert_element_matches(TreeViewPageId::WORKSPACE_SELECTOR_LINK, /#{tree_name}/)
   end

   def assert_no_configured_trees_for_a_project_on_select_tree_widget
     assert_equal('(no configured trees)', @browser.get_eval("#{class_locator('notes', 0)}.innerHTML.strip()"))
   end

   def assert_switch_to_tree_view_link_present_on_action_bar
     @browser.assert_element_present("css=a[title='Switch to tree view']")
   end

   def assert_switch_to_tree_view_link_not_present_on_action_bar
     @browser.assert_element_not_present("css=a[title='Switch to tree view']")
   end

   def assert_trees_available_in_select_trees_drop_down_for(project, *tree_names)
     tree_names.each do |tree_name|
       @browser.assert_element_present("link=#{tree_name}")
     end
   end

   def assert_hierarchy_view_selected
     @browser.assert_element_not_present(TreeViewPageId::HIRERARCHY_LINK_ID)
   end

    def assert_quick_add_link_present_on_root
    @browser.assert_element_not_present(TreeViewPageId::NODE_ADD_NEW_CARD_NODE_ID)
   end

   def assert_quick_add_link_present_on_cards(*cards)
     cards.each do |card|
       assert_quick_add_link_present_on_card(card)
     end
   end

   def assert_quick_add_link_present_on_card(card)
     assert_cards_present(card)
     @browser.assert_element_present(node_add_new_cards(card))
   end

   def assert_quick_add_link_not_present_on_card(card)
     assert_cards_present(card)
     @browser.assert_element_not_present(node_add_new_cards(card))
   end

   def assert_remove_button_present(number)
     (1..number).each { |i| @browser.assert_element_not_present(class_locator("remove-button")[i]) }
   end

   def assert_add_button_present
     @browser.assert_element_present(class_locator("add-button"))
   end

   def assert_card_name_on_quick_add_row(line_number, card_name)
    @browser.assert_value(class_locator('card-name-input',line_number), card_name)
   end

  def assert_card_types_present_on_quick_add(*types)
    with_open_card_type_select_dropdown do
      types.each do |type|
        @browser.assert_visible(quick_add_card_type_option(type))
      end
    end
  end

  def assert_card_types_not_present_on_quick_add(*types)
    with_open_card_type_select_dropdown do
      types.each do |type|
        @browser.assert_element_not_present(quick_add_card_type_option(type))
      end
    end
  end

  def assert_tree_view_tool_bar_present
    @browser.assert_element_present(TreeViewPageId::TREE_VIEW_TOOL_BAR_ID)
  end

  def assert_tree_filter_present
    @browser.assert_element_present(TreeViewPageId::TREE_FILTER_CONTAINER)
  end

  def assert_quick_search_on_tree_present
    @browser.assert_element_present(TreeViewPageId::TREE_INCREMENTAL_SEARCH_ID)
  end

  def assert_remove_card_link_not_present_on_card_in_tree_view(card)
    assert_cards_present(card)
    @browser.assert_element_not_present(node_card_remove_link(card))
  end

  def click_card_type_select_link
    @browser.click(TreeViewPageId::CARD_TYPE_SELECT_DROPDOWN)
  end

  def with_open_card_type_select_dropdown(&block)
    if(@browser.is_element_present(TreeViewPageId::TREE_CARDS_QUICK_ADD_FORM))
      click_card_type_select_link
      yield
    end
    click_card_type_select_link
  end

  def assert_tree_present_in_tree_selection_drop_down(tree)
    @browser.assert_element_present(tree_selector_id(tree))
  end


  def assert_tree_selection_droplist_present
    @browser.assert_element_present(TreeViewPageId::WORKSPACE_SELECTOR_LINK)
  end

  def assert_tree_selection_droplist_not_present
    @browser.assert_element_not_present(TreeViewPageId::WORKSPACE_SELECTOR_LINK)
  end

  def assert_confirm_box_for_remove_tree_node_present
    @browser.assert_element_present(TreeViewPageId::CONFIRM_BOX_ID)
    @browser.assert_element_present("//input[@value='Remove Parent and Children']")
    @browser.assert_element_present("//input[@value='Remove Parent Card']")
    @browser.assert_element_present("//input[@value='Cancel']")
  end

  def assert_confirm_box_for_remove_tree_node_not_present
    @browser.assert_element_not_present(TreeViewPageId::CONFIRM_BOX_ID)
    @browser.assert_element_not_present("//input[@value='This card and its children']")
    @browser.assert_element_not_present("//input[@value='Just this card']")
    @browser.assert_element_not_present("//input[@value='Cancel']")
  end

  def assert_nodes_collapsed_in_tree_view(*cards)
    cards.each do |card|
      raise("card #{card.number} is not collapsed") unless @browser.is_element_present css_locator("div#twisty_for_card_#{card.number} > a.collapsed")
    end
  end

  def assert_nodes_expanded_in_tree_view(*cards)
    cards.each do |card|
      raise("card #{card.number} is not expanded") unless @browser.is_element_present css_locator("div#twisty_for_card_#{card.number} > a.expanded")
    end
  end

  def assert_view_tree_configuration_present
    @browser.assert_element_present(TreeViewPageId::TREE_CONFIGURE_WIDGET_BUTTON)
  end

end
