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

class ThreadLocalCacheTest < ActiveSupport::TestCase
  def test_get_nil_if_key_is_not_set_to_a_value
    assert_nil ThreadLocalCache.get("dddd")
  end

  def test_get_value_after_set_a_value
    value = Object.new
    ThreadLocalCache.set("dddd", value)
    assert_same value, ThreadLocalCache.get("dddd")
  end

  def test_get_value_after_set_a_value_through_get_block
    value = Object.new
    assert_same value, ThreadLocalCache.get("dddd") { value }
    assert_same value, ThreadLocalCache.get("dddd")
  end

  def test_get_nil_after_set_value_get_cleared
    value = Object.new
    ThreadLocalCache.set("dddd", value)
    ThreadLocalCache.clear!
    assert_nil ThreadLocalCache.get("dddd")
  end

  def test_clear_should_not_clear_other_thread_locals
    Thread.current[:test_1] = 'xxxx'
    ThreadLocalCache.clear!
    assert_equal 'xxxx', Thread.current[:test_1]
  end

  def test_single_cache_entry_with_key
    ThreadLocalCache.set("ddd", 123)
    assert_equal 123, ThreadLocalCache.get("ddd")
    ThreadLocalCache.clear('ddd')
    assert_equal nil, ThreadLocalCache.get("ddd")
  end

  def test_get_assn
    with_first_project do |project|
      d = ThreadLocalCache.get_assn(project.team, :deliverable)
      assert_equal project, d
      assert_equal d.object_id, ThreadLocalCache.get_assn(project.team, :deliverable).object_id

      um = project.team.user_memberships.first
      assert_equal d, ThreadLocalCache.get_assn(um, :group, :deliverable)
    end
  end

  def test_should_include_app_namespace_in_cache_key
    MingleConfiguration.with_app_namespace_overridden_to('site1') do
      ThreadLocalCache.set("ddd", 123)
    end
    MingleConfiguration.with_app_namespace_overridden_to('site2') do
      ThreadLocalCache.set("ddd", 321)
    end

    MingleConfiguration.with_app_namespace_overridden_to('site1') do
      assert_equal 123, ThreadLocalCache.get("ddd")
    end
    MingleConfiguration.with_app_namespace_overridden_to('site2') do
      assert_equal 321, ThreadLocalCache.get("ddd")
    end
  end
end
