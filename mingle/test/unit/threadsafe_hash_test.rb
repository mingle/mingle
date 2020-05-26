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
require File.join(File.dirname(__FILE__), "..", '..', 'lib', 'threadsafe_hash')
class ThreadsafeHashTest < Test::Unit::TestCase
  def test_respond_to
    hash = ThreadsafeHash.new
    assert hash.respond_to?(:[])
    assert hash.respond_to?(:[]=)
  end

  def test_method_missing
    hash = ThreadsafeHash.new
    assert_raise NoMethodError, /undefined method `aaa' for \#\<ThreadsafeHash/ do
      hash.aaa
    end
  end

  def test_hash_behaviours
    hash = ThreadsafeHash.new
    hash['a'] = 'b'
    assert_equal 'b', hash['a']
    assert_equal 'b', hash.delete('a')
    assert_nil hash['a']
  end

  # this test need 34 sec to run, only enable it when you need, or changed anything inside ThreadsafeHash
  def xtest_hash_behaviours_threadsafe
    hash = ThreadsafeHash.new
    threads = []
    100_000.times do |index|
      threads << Thread.start do
        5.times do |ii|
          hash["#{index}-#{ii}"] = "#{index}+#{ii}"
        end
        5.times do |ii|
          assert_equal "#{index}+#{ii}", hash["#{index}-#{ii}"]
          hash.delete("#{index}-#{ii}")
        end
      end
    end
    threads.each {|t| t.join}
  end
end
