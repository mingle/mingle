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

class ProjectCacheTest < ActiveSupport::TestCase

  class ProjectVersionKeyStore
    attr_accessor :store

    def initialize(store={})
      @store = store
    end

    def cache_key(project_identifier)
      @store[project_identifier] ||= 0
    end

    def project_version_key(project_identifier)
      @store[project_identifier]
    end
    
    def invalidate(project_identifier)
      @store[project_identifier] = @store[project_identifier].to_i + 1
    end
  end

  def setup
    @project_version_key_store = ProjectVersionKeyStore.new
    @cache = ProjectCache.new(:project_version_key_store => @project_version_key_store)
  end

  def test_should_return_nil_when_nothing_is_put_into_cache
    assert_nil @cache['key']
  end

  def test_should_return_nil_when_cache_key_store_has_no_knowledge_of_cached_object
    @cache['key'] = OpenStruct.new(:project_cache_key => nil)
    assert_equal nil, @cache['key']
  end
  
  def test_should_be_able_to_cache_multiple_objects_against_a_key
    obj1 = create_object('key')
    obj2 = create_object('key')
    obj3 = create_object('key')
    @cache['key'] = obj1
    @cache['key'] = obj2
    @cache['key'] = obj3
    assert_equal obj3, @cache['key']
    assert_equal obj2, @cache['key']
    assert_equal obj1, @cache['key']
  end

  def test_should_not_be_retrieve_more_objects_than_have_been_added
    @cache['key'] = create_object('key')
    @cache['key']
    assert_equal nil, @cache['key']
  end

  def test_should_be_able_to_invalidate_cache_when_single_value_is_stored_for_a_key
    @cache['key'] = create_object('key')
    invalidate('key')
    assert_nil @cache['key']
  end

  def test_be_able_to_invalidate_cache_when_multiple_values_are_stored_for_a_key
    @cache['key'] = create_object('key')
    @cache['key'] = create_object('key')
    invalidate('key')
    assert_nil @cache['key']
  end

  def test_should_return_the_number_of_objects_currently_in_the_cache_as_total_count
    obj1 = create_object('key')
    obj2 = create_object('key')
    obj3 = create_object('another_key')
    @cache['key'] = obj1
    @cache['key'] = obj2
    @cache['another_key'] = obj3
    @cache['key']
    assert_equal 2, @cache.total_count
  end

  def test_clear_all_cache
    @cache['key'] = create_object('key')
    @cache['key2'] = create_object('key2')
    @cache.clear
    assert_equal 0, @cache.total_count
  end

  def test_should_remove_all_garbage_objects_created_by_object_version_invalidation
    @cache['key'] = create_object('key')
    invalidate('key')
    @cache.clear_garbage_objects
    assert_equal 0, @cache.total_count
  end

  def test_should_remove_all_garbage_objects_created_by_object_expiration
    @cache = ProjectCache.new(:expires => 0.01, :project_version_key_store => @project_version_key_store)
    @cache['key'] = create_object('key')
    sleep 0.1

    @cache.clear_garbage_objects
    assert_equal 0, @cache.total_count
  end

  def test_should_ignore_stored_invalidated_object
    @project_version_key_store.store['key'] = 2
    @cache['key'] = OpenStruct.new(:project_cache_key => 1)

    assert_equal nil, @cache['key']
    assert_equal 1, @cache.total_count
  end

  def test_clear_garbage_objects_should_also_clear_the_invalidated_object_stored
    @project_version_key_store.store['key'] = 2
    @cache['key'] = OpenStruct.new(:project_cache_key => 1)

    assert_equal 1, @cache.total_count
    @cache.clear_garbage_objects
    assert_equal 0, @cache.total_count
  end

  def test_should_be_able_to_limit_project_size_stored
    @project_version_key_store = ProjectVersionKeyStore.new
    @cache = ProjectCache.new(:project_version_key_store => @project_version_key_store, :max => 1)
    @cache['key1'] = create_object('key1')
    sleep 0.01
    @cache['key2'] = create_object('key2')
    assert_equal 2, @cache.total_count
    @cache.clear_garbage_objects

    assert_equal 1, @cache.total_count
    assert_equal nil, @cache['key1']
    assert @cache['key2']
  end

  def test_should_turn_off_cache_if_project_cache_max_size_is_less_than_1
    @project_version_key_store = ProjectVersionKeyStore.new
    @cache = ProjectCache.new(:project_version_key_store => @project_version_key_store, :max => 0)
    @cache['key1'] = create_object('key1')
    assert_nil @cache['key1']
    assert_equal 0, @cache.total_count
  end

  def test_stats
    assert_equal 0, @cache.stats.size

    @cache['key1'] = create_object('key1')

    assert_equal 0, @cache.stats.size

    @cache['key1']
    assert_equal 1, @cache.stats.size
    assert_equal 'key1', @cache.stats[0].key
    assert_equal 1, @cache.stats[0].total_gets
    assert_equal 1, @cache.stats[0].total_hits
    assert_equal '100%', @cache.stats[0].hit_rate

    @cache['key1']
    assert_equal 1, @cache.stats.size
    assert_equal 'key1', @cache.stats[0].key
    assert_equal 2, @cache.stats[0].total_gets
    assert_equal 1, @cache.stats[0].total_hits
    assert_equal '50%', @cache.stats[0].hit_rate

    @cache['key2'] = create_object('key2')
    obj2 = @cache['key2']
    @cache['key2'] = obj2
    @cache['key2']

    assert_equal 2, @cache.stats.size
    key1_stats = @cache.stats.detect {|stat| stat.key == 'key1'}
    key2_stats = @cache.stats.detect {|stat| stat.key == 'key2'}
    assert_equal 2, key1_stats.total_gets
    assert_equal 1, key1_stats.total_hits
    assert_equal '50%', key1_stats.hit_rate

    assert_equal 2, key2_stats.total_gets
    assert_equal 2, key2_stats.total_hits
    assert_equal '100%', key2_stats.hit_rate

    stats = ProjectCache::Stat.sum('All', @cache.stats)
    assert_equal 3, stats.size
    assert_equal 'All', stats[0].key
    assert_equal 4, stats[0].total_gets
    assert_equal 3, stats[0].total_hits
    assert_equal '75%', stats[0].hit_rate
  end

  def create_object(key, project_cache_key=1)
    @project_version_key_store.store[key] = project_cache_key
    OpenStruct.new(:project_cache_key => project_cache_key)
  end

  def invalidate(key)
    @project_version_key_store.invalidate(key)
  end
end
