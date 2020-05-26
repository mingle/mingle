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

class Card
  module CardRanking
    RANK_COLUMN = "project_card_rank"
    RANK_MIN = BigDecimal.new("-18446744073709551616.0")
    RANK_MAX = BigDecimal.new("18446744073709551616.0") # 2 ** 64
    BIG_TWO = BigDecimal.new("2.0")

    THRESHOLD = BigDecimal.new("0.0000001")

    def self.included(base)
      base.class_eval do |variable|
        alias_method :rank, RANK_COLUMN.to_sym
      end

      base.send(:include, InstanceMethods)
      base.extend(ClassMethods)

      base.named_scope :higher_than, lambda {|r| {:conditions => ["#{RANK_COLUMN} > ?", r]}}
      base.named_scope :lower_than, lambda {|r| {:conditions => ["#{RANK_COLUMN} < ?", r]}}

      base.after_update :create_rank_event
      base.before_create :rank_as_last_card
    end

    module ClassMethods

      def sig_figs
        # mostly for tests, but may be useful otherwise
        return $force_max_sig_figs unless $force_max_sig_figs.nil?

        # postgres has support for tens of thousands of sig figs in its numeric type (http://www.postgresql.org/docs/9.4/static/datatype-numeric.html)
        # oracle only supports 38 sig figs (http://docs.oracle.com/cd/B19306_01/olap.102/b14346/dml_datatypes002.htm#CJACDECG)
        connection.database_vendor == :oracle ? 38 : 0
      end

      # reduce significant digits to database limits
      def reduce(value)
        return value if sig_figs == 0
        value.mult(1, sig_figs)
      end

      # test if the midpoint will come too close to its bounds after significant digit reduction
      def rank_collision_with_bounds?(min, max)
        reduce((max - min) / BIG_TWO) < THRESHOLD
      end

      def calculate_preceding_rank(card)
        min, max = neighboring_ranks(card, :following)
        reduce((min + max) / BIG_TWO)
      end

      def calculate_succeeding_rank(card)
        min, max = neighboring_ranks(card, :leading)
        reduce((min + max) / BIG_TWO)
      end

      def next_neighboring_rank(card)
        higher_than(card.rank).minimum(RANK_COLUMN)
      end

      def prev_neighboring_rank(card)
        lower_than(card.rank).maximum(RANK_COLUMN)
      end

      def neighboring_ranks(first_neighbor, type)
        if type == :leading
          min = first_neighbor.rank
          max = (succ = next_neighboring_rank(first_neighbor)).nil? ? RANK_MAX : succ
        else
          min = (prev = prev_neighboring_rank(first_neighbor)).nil? ? RANK_MIN : prev
          max = first_neighbor.rank
        end
        [min, max]
      end

      def last_rank
        maximum(RANK_COLUMN)
      end

      def should_redistribute?(first_neighbor, type)
        min, max = neighboring_ranks(first_neighbor, type)
        rank_collision_with_bounds?(min, max)
      end

      def redistribute_card_rankings
        card_count = count()
        range = (RANK_MAX / BIG_TWO) - RANK_MIN
        interval = range / (card_count + 1)

        cards_table_name = connection.safe_table_name(Card.table_name)
        connection.redistribute_project_card_rank(cards_table_name, RANK_MIN, interval.to_i)
      end

    end

    module InstanceMethods

      def rerank(params)
        params = params.blank? ? {} : params

        if leading_card_number = params[:leading_card_number]
          leading_card = project.cards.find_by_number(leading_card_number)
          if Card.should_redistribute?(leading_card, :leading)
            Card.redistribute_card_rankings
            leading_card.reload
          end
          insert_after leading_card
        elsif following_card_number = params[:following_card_number]
          following_card = project.cards.find_by_number(following_card_number)
          if Card.should_redistribute?(following_card, :following)
            Card.redistribute_card_rankings
            following_card.reload
          end
          insert_before following_card
        end
      end

      def rank_as_last_card
        min = (last = Card.last_rank).nil? ? RANK_MIN : last

        if Card.rank_collision_with_bounds?(min, RANK_MAX)
          Card.redistribute_card_rankings
          rank_as_last_card
        else
          rank = Card.reduce((min + RANK_MAX) / BIG_TWO)
          write_attribute(RANK_COLUMN, rank)
        end
      end

      # can't shove this into CardVersionEvent because rank is
      # updated AFTER the CardVersionEvent is created, so
      # CardVersionEvent can only see an outdated rank at the
      # time of creation, so we create an event post-rerank
      def create_rank_event
        return unless project_card_rank_changed? && !project_card_rank.blank?
        LiveOnlyEvents::CardRank.create_for(project, self)
      end

      def insert_before(card)
        rank = Card.calculate_preceding_rank(card)
        update_attribute(RANK_COLUMN, rank)
      end

      def insert_after(card)
        rank = Card.calculate_succeeding_rank(card)
        update_attribute(RANK_COLUMN, rank)
      end

    end

  end
end
