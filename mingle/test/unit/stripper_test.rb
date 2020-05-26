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

class StripperTest < Test::Unit::TestCase
  include Stripper
  def test_sanitize_values_of_hash
    assert_equal({:a => 'hello'}, sanitize_string_value({:a => '<b>hello</b>'}))
  end
  
  def test_sanitize_string_values_should_leave_non_strings_unchanged
    assert_equal({:a => 1}, sanitize_string_value({:a => 1}))
  end

  def test_sanitize_string_values_should_strip_string_values_in_sub_array
    assert_equal({:a => ['hello', 'world']}, sanitize_string_value({:a => ['<a>hello</a>', '<b>world</b>']}))
  end

  def test_sanitize_string_values_should_strip_string_values_in_sub_hash
    assert_equal({:a => ['hello', {:b => 'world'}]}, sanitize_string_value({:a => ['<a>hello</a>', {:b => '<b>world</b>'}]}))
  end
end
