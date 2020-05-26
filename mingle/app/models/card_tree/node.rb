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

class CardTree::Node
  attr_accessor :parent
  attr_reader :children, :tree_config, :name, :number, :partial_tree_card_count, :position, :full_tree_card_count
  attr_writer :raw_level
  
  def initialize(name, number, tree_config, card_tree, partial_tree_card_count, full_tree_card_count, position, level_offset)
    @tree_config = tree_config
    @name = name
    @children = []
    @number = number
    @raw_level = 0
    @card_tree = card_tree
    @partial_tree_card_count = partial_tree_card_count
    @full_tree_card_count = full_tree_card_count
    @position = position
    @level_offset = level_offset || 0
  end

  def card_type
  end
  
  def html_id
    "node_#{@number}"
  end
  
  def expanded?
    has_visible_children?
  end
  
  def has_children?
    partial_tree_card_count > 0
  end
  
  def has_visible_children?
    @children.size > 0    
  end
  
  def root?
    !@parent
  end
  
  def level
    @raw_level + @level_offset
  end
  
  def descendants
    (@children.dup).tap do |descendants|
      descendants << @children.collect { |child| child.descendants }
    end.flatten
  end
  
  def each_descendant(options={}, &block)
    yield(self) unless options[:exclude_self]
    children.each { |child| child.each_descendant(&block) }
  end
  
  def each_descendant_with_index(options={}, &block)
    start_index = options[:start_index].to_i
    yield(self) unless options[:exclude_self]
    children.each { |child| child.each_descendant_with_index({:start_index => start_index + 1}, &block) }
  end
  
  def each_breadth_first_descendant(&block)
    @children.each { |child| yield(child) }
    @children.each do |child|
      child.each_breadth_first_descendant(&block)
    end
  end
  
  def add_child_node(node)
    node.parent = self
    node.raw_level = @raw_level + 1
    @children << node
    node      
  end
  
  def can_be_parent?
    @tree_config.configured?
  end
  memoize :can_be_parent?
      
  def level_in_complete_tree
    @tree_config.level_in_complete_tree(self)
  end
  memoize :level_in_complete_tree
  
  def to_json(options={})
    to_json_properties(options).to_json
  end
  
  def children
    @children.sort_by(&:position)
  end
  
  def children_size
    @children.size()
  end
  
  protected
  def to_json_properties(options={})
    children_json_hashes = options[:exclude_children] ?  [] : children.collect{ |child| child.to_json_properties(options) }
    descendant_count = options[:include_descendant_count] ? partial_tree_card_count : 0
    {
      :name => @name,
      :number => @number,
      :html_id => html_id,
      :expanded => expanded?,
      :descendantCount => @partial_tree_card_count,
      :allCardCount => full_tree_card_count,
      :children => children_json_hashes,
      :acceptableChildCardTypes => @tree_config.all_card_types.collect(&:html_id)}
  end
end
