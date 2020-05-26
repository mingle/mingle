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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class CardCachingStampTest < ActiveSupport::TestCase
  def test_get_stamp
    assert CardCachingStamp.stamp(1)
    assert_equal CardCachingStamp.stamp(1), CardCachingStamp.stamp(1)
  end

  def test_update_stamp
    stamp = CardCachingStamp.stamp(1)
    sleep 0.01
    CardCachingStamp.update([1])
    assert_not_equal stamp, CardCachingStamp.stamp(1)
  end

  def test_update_stamp_with_id_sql
    with_first_project do |proj|
      card = proj.cards.first
      stamp = card.caching_stamp
      sleep 0.01
      CardCachingStamp.update("id = #{card.id}")
      assert_not_equal stamp, card.caching_stamp
    end
  end
end
