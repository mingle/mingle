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

module TreesHelper    
  def tree_js(tree, tab_name, view_params)
    %{
      TreeView.register(new Tree(#{tree.root.to_json}, #{add_children_callback(tree.configuration, tab_name, view_params)}, new CardPopupLoader(#{card_popup_url}),#{@view.expands.to_json}, #{expand_tree_node_function}, #{collapse_tree_node_function}), new Canvas('tree'));
      $('tree_content').style.visibilty = '';
     }
  end
  
  def add_children_callback(tree_config, tab_name, view_params)
    view_params = view_params_without_expands(view_params)
    options = {
      :url => view_params.merge({:controller => 'cards', :action => 'add_children', :tree => tree_config, :tab => tab_name, :tree_style => params[:action]}), 
      :with => "Object.toQueryString({'parent_number': parent, 'child_numbers': children, 'new_cards': newCards=='new_cards', 'tab': #{tab_name.to_json}, 'expands': TreeView.expandedNodesString()})",
      :before => "TreeView.beforeAddChildrenTo(parent)",
      :complete => "TreeView.onAddChildrenComplete(parent)"
    }
    authorized?(options[:url]) ? "function(parent, parent_expanded, children, newCards, all_card_count_of_selected_subtree) { #{remote_function(options)} }" : "null"
  end
  
  def show_quick_add_panel_function(node, tab_name, view_params)
    view_params = view_params_without_expands(view_params)
    options = {
      :url => show_tree_cards_quick_add_action_url_options(node, tab_name, view_params),
      :with => "Object.toQueryString({'parent_expanded': TreeView.tree.root.findNodeByNumber(#{node.number}).expanded, 'expands': TreeView.expandedNodesString()})",
      :before => "if($('#{node.html_id}_inner_element')._isDragging) return;Element.show(#{spinner_id_from(node).to_json}); #{disable_links}",
      :complete => "Element.hide(#{spinner_id_from(node).to_json});if($('no-children-hint')){$('no-children-hint').hide();}",
      :method => :get
    }
    remote_function(options)
  end
  
  def remove_card_from_tree_on_tree_view_action(node, tab_name, view_params)
    view_params = view_params_without_expands(view_params)
    options = {
      :before => "#{disable_links} #{show_spinner(spinner_id_from(node))}", 
      :complete => enable_links,
      :with => "Object.toQueryString({'card_expanded': TreeView.isNodeExpanded(#{node.number}), 'parent_number': TreeView.parentNodeNumber(#{node.number}), 'expands':TreeView.expandedNodesString()})"
    }
    
    %{TreeView.removeCardAction('#{node.number}',
        function() {#{remove_single_card_from_tree_action(node, node.tree_config, tab_name, view_params, options)}},
        function(){#{remove_sub_tree_action(node, node.tree_config, tab_name, view_params, options)}}
      );}
  end
  
  def card_popup_url
    url_for(@view.to_params.merge(:action => 'card_summary',:escape => false)).to_json
  end
  
  private
  def view_params_without_expands(view_params)
    view_params_without_expands = view_params.clone
    view_params_without_expands.delete(:expands)
    return view_params_without_expands
  end
    
end
