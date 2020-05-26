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

class CardTree
  ROOT_CARD_NUMBER = 0
  
  class RootNotInTreeException < StandardError
  end
  
  def self.empty_tree(configuration)
    EmptyTree.new(configuration)
  end
  
  def self.none_root_card_node(card, tree_config)
    tree = CardTree.new(tree_config, {})
    CardNode.new(card, tree_config, tree, 0, 0, 0, 0).tap do |card_node|
      def card_node.root?
        false
      end
    end
  end
  
  def initialize(configuration, options={})    
    @configuration = configuration
    @visible_only = options.delete(:visible_only)
    @level_offset = options.delete(:level_offset)
    @query_builder = TreeQueryBuilder.new(@configuration, options)
  end
  
  def as_card_query
    @visible_only ? @query_builder.visible_tree_card_query : @query_builder.partial_tree_card_query
  end
  
  def card_count
    cards.size
  end

  def reload
    clear_cached_results_for(:cards)
    @root = nil
  end
  
  def root
    init_tree_if_needed
    @root
  end
  
  def name
    @configuration.name
  end
  
  def configuration
    @configuration
  end
  
  def find_node_by_name(card_name)
    find_node{ |n| n.name.downcase == card_name.downcase }
  end
  
  def find_node_by_number(number)
    find_node{ |n| n.number == number }
  end
  
  def find_node_by_card(card)
    find_node_by_number(card.number)
  end
  
  def find_node(&block)
    root.each_descendant{ |node| return node if yield(node)}
    nil
  end
  
  def [](card_name)
    find_node_by_name(card_name)
  end
  
  def nodes
    ret = []
    root.each_descendant{ |node| ret << node  }
    ret
  end
  
  def nodes_without_root
    if block_given?
      root.each_descendant(:exclude_self => true) { |node| yield node }
    else
      ret = []
      root.each_descendant(:exclude_self => true) { |node| ret << node }
      ret
    end    
  end

  def to_json(options={})
    root.to_json(options)
  end
  
  def card_level(card)
    return 0 if card == :root
    @query_builder.card_level_query(card).single_value.to_i + 1
  end
  
  private
  
  def init_tree_if_needed
    return if @root
    @root = @query_builder.use_virtual_root? ? virtual_root : CardNode.new(@query_builder.root_card, @configuration, self, @query_builder.partial_tree_card_count, children_count(@query_builder.root_card), 0, @level_offset)
    card_nodes = card_nodes_by_id
    tree_nodes = {}
    card_nodes.values.each{ |child_node| add_to_parent(child_node, card_nodes, tree_nodes) }
    @root
  end
  
  def add_to_parent(child_node, card_nodes, tree_nodes)
    return @root unless child_node
    return tree_nodes[child_node.id] if tree_nodes[child_node.id]
    parent_card_ids = @configuration.parent_card_ids(child_node.card)
    parent_card_ids = parent_card_ids.reject{ |id| !card_nodes[id] && !tree_nodes[id] }
    parent_node = if (parent_card_ids).empty?
      @root
    elsif parent = tree_nodes[parent_card_ids.last]
      parent
    else
      youngest = parent_card_ids.reverse.detect { |pcid| card_nodes[pcid] }
      youngest_parent = card_nodes.delete(youngest)
      add_to_parent(youngest_parent, card_nodes, tree_nodes)
    end
    card_nodes.delete(child_node.id)
    parent_node.add_child_node(child_node)
    tree_nodes[child_node.card.id] = child_node
    child_node
  end

  def cards
    as_card_query.find_cards
  end
  memoize :cards

  def card_nodes_by_id
    collector = {}
    cards.each_with_index do |c, index|
      collector[c.id] = CardNode.new(c, @configuration, self, children_count(c, :partial), children_count(c), index + 1, @level_offset)
    end
    collector
  end
  
  def children_count(card, tree_selection = :full)
    relationship_established_by_card = @configuration.find_relationship(card.card_type)
    return 0 unless relationship_established_by_card
    rows_with_counts_for_card = split_counts(tree_selection).select { |row| row[relationship_established_by_card.column_name].to_i == card.id }
    rows_with_counts_for_card.inject(0) { |result, row| result += row['count'].to_i }
  end
  
  def virtual_root
    Node.new(name, ROOT_CARD_NUMBER, @configuration, self, self.card_count, @query_builder.full_tree_card_count, 0, @level_offset)
  end
  
  def split_counts(selection = :full)
    @split_counts = {
        :partial => card_counts_of_each_distinct_tree_path_definied_by(@query_builder.partial_tree_card_query), 
        :full => card_counts_of_each_distinct_tree_path_definied_by(@query_builder.full_tree_card_query)
    } unless @split_counts
    @split_counts[selection]
  end
  
  def card_counts_of_each_distinct_tree_path_definied_by(query)
    where_clause = query.to_joins_where_and_group_by_clause_sql
    columns = @configuration.relationships.collect { |r| "#{Card.quoted_table_name}.#{r.column_name}" }.join(', ')
    ActiveRecord::Base.connection.select_all %{
      SELECT #{columns}, COUNT(*) as count
      FROM #{Card.quoted_table_name} 
      #{where_clause}
      GROUP BY #{columns}
      ORDER BY #{columns}
    }
  end  
end
