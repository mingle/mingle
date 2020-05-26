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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

class FileBasedCacheTest < ActiveSupport::TestCase
  def setup
    @cache = DailyHistoryCache.file_store("file_key")
    @cache.clear_store
    login_as_member
  end

  def teardown
    Clock.reset_fake
  end

  def test_save_and_read_data_by_date
    date = "2009-05-14".to_date
    @cache.save(date) {[0,1]}

    assert_equal [[0, 1]], @cache.cached_data_values([date])
  end

  def test_should_get_all_cached_values
    @cache.save("2009-05-14".to_date) {[0,1]}
    @cache.save("2009-05-15".to_date) {[1,2]}

    assert_equal [[0, 1], [1, 2]], @cache.cached_data_values(['2009-05-14'.to_date, '2009-05-15'.to_date])
  end

  def test_should_give_current_data_point_count_for_file_based_cache
    @cache.save("2009-05-14".to_date) {[0,1]}
    @cache.save("2009-05-15".to_date) {[0,1]}

    assert_equal 2, @cache.cached_data_count
  end

  def test_fetch_data_values_when_nothing_saved
    assert_equal [[], []], @cache.cached_data_values(['2009-05-14'.to_date, '2009-05-15'.to_date])

    @cache.save("2009-05-14".to_date) {[0,1]}
    assert_equal [[0,1], []], @cache.cached_data_values(['2009-05-14'.to_date, '2009-05-15'.to_date])
  end

  def test_save_should_call_block_if_data_does_not_exist_for_specific_date
    @cache.save("2009-05-14".to_date) do
      [0,1]
    end

    assert_equal [[0, 1]], @cache.cached_data_values(['2009-05-14'.to_date])

    @cache.save("2009-05-14".to_date) do
      raise "should not call block"
    end

    assert_equal [[0, 1]], @cache.cached_data_values(['2009-05-14'.to_date])
  end

  def test_save_should_not_call_block_if_data_for_specific_date_is_cached
    @cache.save("2009-05-14".to_date) do
      [0,1]
    end
    @cache.clear_store

    @cache.save("2009-05-14".to_date) do
      raise "should not call block"
    end

    assert_equal [[0, 1]], @cache.cached_data_values(['2009-05-14'.to_date])
    Cache.flush_all
    assert_equal [[]], @cache.cached_data_values(['2009-05-14'.to_date])
  end

  def test_save_should_not_call_block_if_data_for_specific_date_exists_in_file
    @cache.save("2009-05-14".to_date) do
      [0,1]
    end
    Cache.flush_all

    @cache.save("2009-05-14".to_date) do
      raise "should not call block"
    end

    assert_equal [[0, 1]], @cache.cached_data_values(['2009-05-14'.to_date])
  end

  def test_save_should_also_cache_data
    date = "2009-05-14".to_date
    @cache.save(date) { [0,1] }
    @cache.clear_store
    assert_equal [[0, 1]], @cache.cached_data_values([date])
    Cache.flush_all
    assert_equal [[]], @cache.cached_data_values([date])
  end

  def test_cached_data_values_should_also_cache_missing_data_fetched_from_store
    date = "2009-05-14".to_date
    @cache.save(date) { [0,1] }
    Cache.flush_all
    assert_equal [[0, 1]], @cache.cached_data_values([date])
    @cache.clear_store
    assert_equal [[0, 1]], @cache.cached_data_values([date])
  end
end
