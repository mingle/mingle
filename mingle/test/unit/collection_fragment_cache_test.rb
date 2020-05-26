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

class CollectionFragmentCacheTest < ActiveSupport::TestCase
  class GeneralCachKeyGen
    def initialize(&block)
      @key_gen = Proc.new(&block)
    end

    def path_for(*args)
      @key_gen[*args]
    end
  end

  class MultiOnlyCache
    def initialize
      @store = {}
    end

    def add(key, value)
      @store[key] = value
    end

    def get_multi(keys)
      keys.inject({}) { |memo, key| memo[key]= @store[key]; memo }
    end
  end

  def setup
    @perform_caching = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true
    @buffer = ActiveSupport::SafeBuffer.new("")
    @key_gen = GeneralCachKeyGen.new {|ele| "key_for_" + ele.to_s }
    @cache_store = MultiOnlyCache.new
  end

  def teardown
    ActionController::Base.perform_caching = @perform_caching
  end

  def test_rendered_result_should_be_append_to_the_buffer
    cache = create_cache(['a', 'b'])
    cache.fragment_for(@buffer, 'a') { @buffer << 'content_for_a' }
    assert_equal 'content_for_a', @buffer
  end

  def test_composite_key
    collection = [['a', 1], ['b', 2]]
    key_gen = GeneralCachKeyGen.new { |element1, element2| ["key_for_"+ element1.to_s, 'key_for_' + element2.to_s].join('/') }

    compose_cache = create_cache(collection, key_gen)
    compose_cache.fragment_for(@buffer, 'a', 1) { @buffer << 'a' }
    compose_cache.fragment_for(@buffer, 'b', 2) { @buffer << 'b' }

    compose_cache = create_cache(collection, key_gen)
    compose_cache.fragment_for(@buffer, 'b', 2) { raise 'should not hit' }
    compose_cache.fragment_for(@buffer, 'a', 1) { raise 'should not hit' }

    assert_equal('abba', @buffer)
  end

  def test_write_once_and_repeatly_read
    cache = create_cache(['a', 'b'])
    cache.fragment_for(@buffer, 'a') { @buffer << 'a' }
    cache.fragment_for(@buffer, 'b') { @buffer << 'b' }

    cache = create_cache(['a', 'b'])

    cache.fragment_for(@buffer, 'b') { raise 'should not hit' }
    cache.fragment_for(@buffer, 'a') { raise 'should not hit' }
    assert_equal('abba', @buffer)
  end

  def test_should_not_cache_when_caching_is_disabled
    ActionController::Base.perform_caching = false
    render_times = 0
    cache = create_cache(['a', 'b'])
    cache.fragment_for(@buffer, 'a') { @buffer << 'a'; render_times +=1  }
    cache.fragment_for(@buffer, 'b') { @buffer << 'b'; render_times +=1  }
    cache.fragment_for(@buffer, 'b') { @buffer << 'b'; render_times +=1  }
    cache.fragment_for(@buffer, 'a') { @buffer << 'a'; render_times +=1  }
    assert_equal('abba', @buffer)
    assert_equal(4, render_times)
  end

  def test_html_safety
    cache = create_cache(['a', 'b'])
    cache.fragment_for(@buffer, 'a') { @buffer << '<bold>'.html_safe }

    assert_equal 'String', @cache_store.get_multi([@key_gen.path_for('a')]).values.first.class.name

    cache = create_cache(['a', 'b'])
    cache.fragment_for(@buffer, 'a') {  }
    cache.fragment_for(@buffer, 'a') {  }
    assert_equal("<bold>" * 3, @buffer)
  end

  private
  def create_cache(collection, key_gen=@key_gen, store=@cache_store)
    CollectionFragmentCache.new(key_gen, collection, store)
  end

end
