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

class MemoizeTest < ActiveSupport::TestCase
  class Sample
    attr_accessor :x
    memoize :x
  end
  class SampleClone
    attr_accessor :x
    memoize :x, :return_clone => true
  end

  class SampleUnmemoize
    attr_accessor :x
    memoize :x
    unmemoize_all
  end

  class SampleCloneUnmemoize
    attr_accessor :x
    memoize :x, :return_clone => true
    unmemoize_all
  end

  class HashSample
    def result=(re)
      @re = re
    end
    def to_inspect(hash)
      @re
    end
    memoize :to_inspect
  end
  
  def test_simple_caching
    o = Sample.new
    o.x = 10
    assert_equal 10, o.x
    o.x = 9
    assert_equal 10, o.x
  end
  
  def test_clearing_cache
    o = Sample.new
    o.x = 10
    o.x
    o.x = 9
    o.clear_cached_results_for(:x)
    assert_equal 9, o.x
  end
  
  def test_should_cache_nil_object
    o = Sample.new
    o.x = nil
    o.x
    o.x = 9
    assert_nil o.x
    
    o = SampleClone.new
    o.x = nil
    o.x
    o.x = 9
    assert_nil o.x
  end

  def test_unmemoize_all
    o = SampleUnmemoize.new
    o.x = '1'
    o.x
    o.x = '2'
    assert_equal '2', o.x
    assert !SampleUnmemoize.method_defined?(:clear_cached_results_for)
  end

  def test_unmemoize_all_with_clone
    assert !SampleCloneUnmemoize.method_defined?(:x_with_returning_clone)
  end

  def test_caching_of_hash_arg
    o = HashSample.new
    o.result = 'cached result'

    assert_equal('cached result', o.to_inspect({'xxx' => 'yyy'}))

    o.result = 'not result'
    assert_equal('cached result', o.to_inspect({'xxx' => 'yyy'}))
  end

  def test_caching_of_method_with_no_args
    @object_with_cached_methods = ClassWithMethodsToBeCached.new
    assert_equal 13,@object_with_cached_methods.thirteen
    assert_equal 13,@object_with_cached_methods.thirteen
    assert_equal 1, @object_with_cached_methods.counter
  end

  def test_caching_of_method_with_single_arg
    @object_with_cached_methods = ClassWithMethodsToBeCached.new
    assert_equal 16,@object_with_cached_methods.square(4)
    assert_equal 16,@object_with_cached_methods.square(4)
    assert_equal 9, @object_with_cached_methods.square(3)
    assert_equal 2, @object_with_cached_methods.counter
  end  

  def test_caching_of_method_with_two_args
    @object_with_cached_methods = ClassWithMethodsToBeCached.new
    assert_equal 11, @object_with_cached_methods.add(4, 7)
    assert_equal 11, @object_with_cached_methods.add(4, 7)
    assert_equal 11, @object_with_cached_methods.add(7, 4)
    assert_equal 5, @object_with_cached_methods.add(3, 2)
    assert_equal 3, @object_with_cached_methods.counter
  end  

  def test_clearing_of_cache
    @object_with_cached_methods = ClassWithMethodsToBeCached.new
    assert_equal 16, @object_with_cached_methods.square(4)
    assert_equal 13, @object_with_cached_methods.thirteen
    @object_with_cached_methods.clear_cached_results_for(:square)
    assert_equal 16,@object_with_cached_methods.square(4)    
    assert_equal 16,@object_with_cached_methods.square(4)    
    assert_equal 3, @object_with_cached_methods.counter
  end

  def test_return_clone_of_cached_results_option
    @object_with_cached_methods = ClassWithMethodsToBeCached.new
    foo_bar_hash = @object_with_cached_methods.foo_bar_hash
    foo_bar_hash[:foo] = :not_bar
    assert_equal :bar, @object_with_cached_methods.foo_bar_hash[:foo]
  end

  def test_do_not_return_clone_unless_option_is_requested
    @object_with_cached_methods = ClassWithMethodsToBeCached.new
    bar_foo_hash = @object_with_cached_methods.bar_foo_hash
    bar_foo_hash[:bar] = :not_foo
    assert_equal :not_foo, @object_with_cached_methods.bar_foo_hash[:bar]
  end
end

class ClassWithMethodsToBeCached

  attr_accessor :counter

  def initialize
    @counter = 0
  end

  def thirteen
    @counter += 1
    13
  end

  def square(arg)
    @counter += 1
    arg * arg
  end

  def add(arg1, arg2)
    @counter += 1
    arg1 + arg2
  end

  def foo_bar_hash
    {:foo => :bar}
  end

  def bar_foo_hash
    {:bar => :foo}
  end

  memoize :thirteen
  memoize :square
  memoize :add
  memoize :foo_bar_hash, :return_clone => true
  memoize :bar_foo_hash
end
