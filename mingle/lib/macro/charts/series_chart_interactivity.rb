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

module SeriesChartInteractivity
  class CardData
    attr_reader :updated_at

    def initialize(data)
      @data = data.slice('name','number')
      @updated_at = DateTime.parse(data['updated_at']) if data['updated_at']
    end

    def to_h
      @data
    end

    def number
      @data['number']
    end
  end

  class CardsData
    attr_reader :cards, :count

    def initialize(cards = [])
      @cards = cards.map { |card| CardData.new(card) }
      @count = cards.count
    end

    def +(another)
      @cards = (self.cards + another.cards).sort_by(&:updated_at).reverse
      @count += another.count
      self
    end

    def -(another)
      card_numbers = another.cards.map(&:number)
      @cards = @cards.reject{|card| card_numbers.include? card.number}
      @count = @count - another.count
      self
    end

    def to_h
      {cards: @cards.take(10).map(&:to_h), count: @count}
    end
  end

  def extract_region_data
    @region_data = self.series.inject({}) do |data_set, series|
      accumulated_data_set = CardsData.new
      accumulated_data_set = get_cumulative_cards(series) if series.down_from?
      series.project.with_active_project do
        cards = cards_for(series)
        cards = extract_cards_for_tree_view(series, cards) if @x_labels_tree.present?
        x_axis_values.each do |k|
          label_for_plot = k || PropertyValue::NOT_SET
          data_set[label_for_plot] ||= {}
          data_set_for_region = cards[label_for_plot] || CardsData.new
          data_set_for_region = get_cumulative_data_set_for_region(series.down_from?, accumulated_data_set, data_set_for_region) if cumulative?
          data_set[label_for_plot][series.label] = data_set_for_region.to_h
        end
        data_set
      end
    end
    @region_data.slice!(*labels_for_plot)
  end

  def extract_region_mql
    @region_mql = {'conditions' => {}, 'project_identifier' => {}}
    self.series.each do |series|
      series.project.with_active_project do
        iterated_keys = []
        normalized_x_axis_values = []
        normalized_x_axis_values = @x_axis_labels.reformat_values_from(x_labels_tree: @x_labels_tree, series_project: series.project, labels: labels_for_plot) if @x_labels_tree.present?
        if cumulative? && @start_index && @start_index > 0
          iterated_keys.push *x_axis_values[0..@start_index - 1]
        end
        labels_for_plot.zip(normalized_x_axis_values).each do |(key, normalized_key)|
          label_for_plot = key || PropertyValue::NOT_SET
          @region_mql['conditions'][label_for_plot] ||= {}
          region_restricted_mql = ''
          if key != @start_label
            iterated_keys.push(normalized_key || key)
            keys = cumulative ? iterated_keys : [iterated_keys.last]
            region_restricted_mql_conditions = CardQuery::MqlGeneration.new(series.query.restrict_with(query_restriction(keys, series.query.columns.first)).conditions)
            region_restricted_mql = region_restricted_mql_conditions.execute
          end
          @region_mql['conditions'][label_for_plot][series.label] = series.down_from? ? series.down_from_mql-region_restricted_mql_conditions : region_restricted_mql
        end
      end
    end
    @region_mql['project_identifier'] = self.series.inject({}) do |project_identifiers, series|
      project_identifiers[series.label] = series.project.identifier
      project_identifiers
    end
  end
  private
  
  def normalize_key(key, series)
    return PropertyValue::NOT_SET unless key || key == PropertyValue::NOT_SET
    first_column = series.query.columns.first
    is_numeric = first_column.respond_to?(:numeric?) && first_column.numeric?
    is_numeric ? key.to_s.to_num(series.project.precision).to_s : key
  end

  def cards_for(series)
    query_column = series.query.columns.first
    region_data_column_selected = %w(name number updated_at).include?(query_column.column_name.downcase)
    columns = [CardQuery::CardNameColumn.new, CardQuery::CardNumberColumn.new]
    columns << query_column unless region_data_column_selected
    columns << CardQuery::CardUpdatedAtColumn.new if cumulative
    CardQuery.new(
        conditions: series.query.conditions,
        columns: columns,
        order_by: [CardQuery::CardOrderColumn.new('updated_at')] + series.query.order_by
    ).values.group_by {|card| query_column.value_from(card, true)}.inject({}) do |card_results, (key, cards)|
      card_results[normalize_key(key, series)] = CardsData.new(cards)
      card_results
    end
  end

  def extract_cards_for_tree_view(series,cards)
    normalized_x_axis_values = @x_axis_labels.reformat_values_from(x_labels_tree: @x_labels_tree, series_project: series.project, labels: labels_for_plot)
    x_axis_values_with_card_numbers = Hash[*normalized_x_axis_values.zip(labels_for_plot).flatten]
    x_axis_values_with_cards = {}
    x_axis_values_with_card_numbers.merge(cards) do |key,oldvalue,newvalue|
      x_axis_values_with_cards[x_axis_values_with_card_numbers[key]]= cards[key]
    end
    x_axis_values_with_cards.stringify_keys!
  end

  def get_cumulative_cards(series)
    CardsData.new(series.down_from_data)
  end

  def get_cumulative_data_set_for_region(down_from, accumulated_data_set, data_set_for_region)
    return accumulated_data_set - data_set_for_region if down_from
    accumulated_data_set + data_set_for_region
  end
end
