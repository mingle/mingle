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


require "test/unit"
require File.expand_path(File.dirname(__FILE__) + '/../../lib/cache_stat')

class CacheStatTest < Test::Unit::TestCase

  def test_get_hit
    stat = CacheStat.new
    stat.get('key')
    assert_equal({:get => 1, :hit => 0}, stat.capture['key'])

    stat.hit('key')
    assert_equal({:get => 1, :hit => 1}, stat.capture['key'])
  end

  def test_hit_rate
    stat = CacheStat.new
    assert_equal '0%', stat.capture.hit_rate('key')
    stat.get('key')
    stat.get('key')
    stat.hit('key')
    assert_equal '50%', stat.capture.hit_rate('key')
    assert_equal '50%', stat.capture.hit_rate
  end

  def test_total_hit
    stat = CacheStat.new
    assert_equal '0%', stat.capture.hit_rate
    stat.get('key1')
    stat.get('key1')
    stat.hit('key1')
    stat.get('key2')
    stat.get('key2')
    stat.hit('key2')
    stat.hit('key2')
    assert_equal '75%', stat.capture.hit_rate
  end
end
