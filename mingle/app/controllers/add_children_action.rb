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

class AddChildrenAction
  attr_reader :children_added, :children_added_in_filter, :warning_messages_for_hidden_nodes, :card_context
  
  def initialize(project, tree_config, params, card_context)
    @project = project
    @params = params
    @tree_config = tree_config
    
    @warning_messages_for_hidden_nodes = []
    @card_context = card_context
    @children_added, @children_added_in_filter = []
    @parent_card = nil
  end
  
  def execute(parent_card, child_cards)
    @parent_card = parent_card
    @already_in_tree = @tree_config.include_card?(child_cards.first)
    @tree_config.add_children_to(child_cards, parent_card)
    @children_added = child_cards.collect{ |card| CardTree.none_root_card_node(card, @tree_config) }
    @children_added_in_filter, children_not_in_filter = partition_children_by_tree_filter(@children_added)
    generate_hidden_children_messages(parent_card, @children_added_in_filter, children_not_in_filter)
    @card_context.add_to_current_list_navigation_card_numbers(@children_added_in_filter.collect(&:number))
  end
  
  def subtree
    CardListView.find_or_construct(@project, @params).workspace.subtree(@parent_card)
  end
  
  def has_warning?
    warning_messages_for_hidden_nodes.any?
  end
  
  def has_child_in_filter?
    children_added_in_filter.any?
  end
  
  private
  
  def generate_hidden_children_messages(parent_card, children_in_filter, children_not_in_filter)
    if children_not_in_filter.any?
      count = children_not_in_filter.size
      @warning_messages_for_hidden_nodes << nodes_not_show_message(count, parent_name_from(parent_card))
    end
  end
  
  def parent_name_from(parent_card)
    parent_card == :root ? @tree_config.name : parent_card.number_and_name
  end
    
  def nodes_not_show_message(count, parent_card_name)
    action = @already_in_tree ? 'updated in' : 'added to'
    "#{'cards'.enumerate(count)} #{'was'.plural(count)} #{action} #{parent_card_name.bold}, but #{'is'.plural(count)} not shown because #{count == 1 ? 'it does' : 'they do'} not match the current filter."
  end
  
  def partition_children_by_tree_filter(children)
    # do we need it, or just for the test??
    @params[:style] ||= 'tree'
    @params[:tree_name] ||= @tree_config.name
    
    view = CardListView.find_or_construct(@project, @params)
    children.partition{|node| view.include_number?(node.number) }
  end
end
