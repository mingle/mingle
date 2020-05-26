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

class CardTree::TreeQueryBuilder
  include SqlHelper

  attr_reader :root_card, :fetch_descriptions

  def initialize(configuration, query_options)
    @configuration = configuration
    @root_card = query_options[:root] || :root
    @base_query = query_options[:base_query]
    @order_by = query_options[:order_by]
    @expanded_cards = @configuration.find_cards_by_numbers(query_options[:expanded])
    @fetch_descriptions = query_options[:fetch_descriptions]
    @base_query.fetch_descriptions = @fetch_descriptions if @base_query
    validate_root_card
  end

  def visible_tree_card_query
    condition = CardQuery::And.new(subtree_condition, connective_conditions)
    tree_query = CardQuery.new(:conditions => condition, :order_by => @order_by, :fetch_descriptions => fetch_descriptions)
    @base_query ? @base_query.restrict_with(tree_query) : tree_query
  end

  def full_tree_card_query
    CardQuery.new(:conditions => @configuration.in_tree_condition, :order_by => @order_by, :fetch_descriptions => fetch_descriptions)
  end

  def partial_tree_card_query
    tree_query = CardQuery.new(:conditions => subtree_condition, :order_by => @order_by, :fetch_descriptions => fetch_descriptions)
    @base_query ? @base_query.restrict_with(tree_query) : tree_query
  end

  def card_level_query(card)
    card_ids_in_partial_tree_query @configuration.parent_card_ids(card)
  end

  def use_virtual_root?
    @root_card == :root
  end

  def partial_tree_card_count
    partial_tree_card_query.card_count
  end

  def full_tree_card_count
    full_tree_card_query.card_count
  end

  memoize_all :visible_tree_card_query, :partial_tree_card_query, :partial_tree_card_count, :full_tree_card_query, :full_tree_card_count

  private

  def subtree_condition
    CardQuery::And.new(
        @configuration.in_tree_condition,
        @configuration.sub_tree_condition(@root_card))
  end

  ### a card is connected to a visible tree when its all parent relationships are connective
  def connective_conditions
    conditions = @configuration.relationship_map.collect {|relationship| connective_condition_for(relationship)}
    CardQuery::And.new(*conditions)
  end

  ### a relationship is connective under these three situations
  #   * parent is skipped (such as story connect to release directly)
  #   * parent is excluded in the tree (filtered out)
  #   * parent is expanded
  def connective_condition_for(relationship)
    relationship_column = CardQuery::Column.new(relationship.name)
    skipped = CardQuery::IsNull.new(relationship_column)
    excluded = CardQuery::Not.new(CardQuery::ImplicitIn.new(relationship_column, partial_tree_card_query.select_column_query('number')))
    expanded = CardQuery::NumbersExplicitIn.new(relationship_column, @expanded_cards.collect(&:number))
    @expanded_cards.empty? ? CardQuery::Or.new(skipped, excluded) : CardQuery::Or.new(skipped, excluded, expanded)
  end

  def validate_root_card
    return if @root_card == :root
    unless card_in_partial_tree?(@root_card)
      raise CardTree::RootNotInTreeException.new("specified root #{@root_card} is not in tree #{@configuration.name.bold}")
    end
  end

  def card_in_partial_tree?(card)
    query = CardQuery.parse("number = #{card.number}")
    restrict_with_partial_tree_condition!(query)
    query.card_count > 0
  end

  def card_ids_in_partial_tree_query(ids)
    query = CardQuery.new(
      :columns => [CardQuery::AggregateFunction.new('count', CardQuery::Star.new)],
      :conditions => CardQuery::ExplicitIn.new(CardQuery::CardIdColumn.new, ids))
    restrict_with_partial_tree_condition!(query)
    query
  end

  def restrict_with_partial_tree_condition!(query)
    query.restrict_with!(@configuration.in_tree_condition)
    query.restrict_with!(@base_query) if @base_query
  end
end
