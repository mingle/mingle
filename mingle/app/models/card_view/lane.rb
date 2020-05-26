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
  class Lane
    include LaneSupport

    attr_accessor :visible
    attr_reader :property_value
    delegate :header_card, :to => :@property_value

    def initialize(project, group, property_value, visible=true)
      @project = project
      @group = group
      @property_value = property_value
      @visible = visible
      @cards = []
      yield(self)
    end

    def axis
      "lane"
    end

    def toggle
      @visible = !@visible
    end

    def title
      property_value.grid_view_display_value
    end

    def identifier
      @property_value.lane_identifier
    end
    memoize :identifier

    def value
      @property_value.db_identifier
    end

    def url_identifier
      @property_value.url_identifier
    end

    def html_id
      "lane_#{Digest::MD5::new.update(@property_value.db_identifier.to_s)}"
    end

    def adopt_cards(lane_cards)
      return unless visible

      @cards = lane_cards
      if @property_value.property_definition.is_a?(TreeRelationshipPropertyDefinition)
        tree_config = @property_value.property_definition.tree_configuration
        id_numbers = Hash[@cards.collect{|c| [c.id.to_i, c.number]}]
        @cards.each do |card|
          card.ancestors = tree_config.parent_card_ids(card).collect{|id| id_numbers[id.to_i]}.compact
        end
      end
    end

    def cards
      raise "for performance reason loading cards for none visible lane is disabled" unless visible
      @cards
    end

    def count(query)
      # This might be unused...
      @property_value.card_count(query)
    end

    def can_reorder?
      @group.supports_direct_manipulation?(:lane) && title != PropertyValue::NOT_SET && ((EnumeratedPropertyDefinition === @property_value.property_definition && !@property_value.property_definition.is_numeric?) || CardTypeDefinition === @property_value.property_definition)
    end

    def can_hide?
      @group.supports_direct_manipulation?(:lane) && !sole_lane?
    end

    private

    def sole_lane?
      @group.visibles(:lane).map(&:identifier) == [self.identifier]
    end

  end
end
