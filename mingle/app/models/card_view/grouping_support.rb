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

module CardView
  module GroupingSupport

    def lanes
      return [UngroupLane.new(project, cards, self)] unless lane_property_definition

      query = @view.as_card_query
      cards_group = CardsGroup.new(self.cards, lane_property_definition)
      property_lanes = lane_property_definition.property_values.collect { |p| create_lane(p, cards_group.cards(p)) }

      if lane_property_definition.weak_ordered?
        property_lanes = property_lanes.smart_sort_by(&:title)
      end

      if lane_property_definition.nullable?
        not_set_property_value = lane_property_definition.property_value_from_db(nil)
        property_lanes.unshift create_lane(not_set_property_value, cards_group.cards(not_set_property_value))
      end

      ensure_at_least_one_visible(property_lanes)

      property_lanes
    rescue CardQuery::DomainException => e
      Rails.logger.debug { "Ignore card query parsing error: #{e.message}\n#{e.backtrace.join("\n")}" }
      []
    end
    memoize :lanes

    def rows
         grid_row_property_values = property_values_for(grid_cards)

         result = [].tap do |rows|
           visibles(:lane).each do |lane|
             t = Time.now
             lane.group_by_row_property(grid_row_property_values).each_with_index do |cell, row_index|
               rows[row_index] ||= CardView::Row.new(project, self)
               rows[row_index] << cell
             end
           end
         end

         result.each do |r|
           r.visible = @rows_specified ? @rows_param.ignore_case_include?(r.identifier) : r.cards.any?
         end

      ensure_at_least_one_visible(result)
      result
    end
    memoize :rows

    def lane(identifier)
      lanes.detect { |l| l.identifier == identifier.to_s }
    end

    def row(identifier)
      rows.detect { |r| r.identifier == identifier.to_s }
    end


    private
    def property_values_for(cards)
      return unless row_property_definition
      cards_group_by_row_property_value = cards.group_by do |card|
        row_property_definition.property_value_on(card).db_identifier
      end

      not_set = row_property_definition.property_value_from_db(nil)
      values = row_property_definition.property_values.values
      values.unshift not_set if (row_property_definition.nullable? && !values.include?(not_set))

      property_values = row_property_definition.sort(values).select do |value|
        mapped_cards = cards_group_by_row_property_value[value.db_identifier]
        !mapped_cards.nil? || @rows_param.ignore_case_include?(value.lane_identifier)
      end
      property_values.empty? ? [values.first] : property_values
    end

    def grid_cards
      grid_cards = []
      visibles(:lane).each do |lane|
        (grid_cards << lane.cards).flatten!
      end
      grid_cards
    end

    def ensure_at_least_one_visible(lanes_or_rows)
      return if lanes_or_rows.any?(&:visible)
      lanes_or_rows.first.visible = true
    end

    def create_lane(prop_value, lane_cards)
      Lane.new(@project, self, prop_value) do |l|
        l.adopt_cards(lane_cards)
        l.visible = lane_visible?(l)
      end
    end

    def lane_visible?(lane)
      return @lanes_param.ignore_case_include?(lane.identifier) if @lanes_specified
      return false if cards.empty?
      lane.cards.any?
    end

  end
end
