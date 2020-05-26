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

require File.expand_path("../../unit_test_helper", File.dirname(__FILE__))

class RedistributeCardRanksTest < ActiveSupport::TestCase
  def setup
    login_as_admin
  end

  def test_applying_fix_will_evenly_redistribute_card_ranks
    with_new_project do |project|
      card1, card2, card3 = (1..3).map{ |i|
        create_card!(:name => i.to_s).tap { |c|
          c.update_attribute(Card::CardRanking::RANK_COLUMN, BigDecimal.new(i.to_s))
        }
      }
      assert_equal BigDecimal.new("1.0"), card1.rank
      assert_equal BigDecimal.new("2.0"), card2.rank
      assert_equal BigDecimal.new("3.0"), card3.rank

      DataFixes::RedistributeCardRanks.apply

      interval = DataFixes::RedistributeCardRanks::INTERVAL
      assert_equal min_rank + interval, card1.reload.rank
      assert_equal card1.rank + interval, card2.reload.rank
      assert_equal card2.rank + interval, card3.reload.rank
    end
  end

  private

  def min_rank
    Card::CardRanking::RANK_MIN
  end
end
