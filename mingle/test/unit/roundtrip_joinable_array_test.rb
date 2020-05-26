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

class RoundtripJoinableArrayTest < ActiveSupport::TestCase
  def test_parse_str_split_by_comma_to_array
    assert_equal ['1', '2'], RoundtripJoinableArray.from_str('1,2')
    assert_equal ['1,2', '3'], RoundtripJoinableArray.from_str('1\\,2,3')
    assert_equal ['1,2\\', '3'], RoundtripJoinableArray.from_str('1\\,2\\\\,3')
    assert_equal ['1\\,2\\', '\\\\3'], RoundtripJoinableArray.from_str('1\\\\\\,2\\\\,\\\\\\\\3')
  end
  
  def test_array_to_s_splited_by_comma
    assert_equal '', RoundtripJoinableArray.from_array([nil]).to_s
    assert_equal '1,2', RoundtripJoinableArray.from_array(['1', '2']).to_s
    assert_equal '1\\,2,3', RoundtripJoinableArray.from_array(['1,2', '3']).to_s
    assert_equal '1\\,2\\\\,3', RoundtripJoinableArray.from_array(['1,2\\', '3']).to_s
    assert_equal '1\\\\\\,2\\\\,\\\\\\\\3', RoundtripJoinableArray.from_array(['1\\,2\\', '\\\\3']).to_s
  end
  
  def test_roundtrip
    assert_equal '1\\,2\\\\,3', RoundtripJoinableArray.from_str('1\\,2\\\\,3').to_s
    assert_equal ['1\\,2\\', '\\\\3'], 
      RoundtripJoinableArray.from_str(RoundtripJoinableArray.from_array(['1\\,2\\', '\\\\3']).to_s)
    
    assert_equal [], RoundtripJoinableArray.from_str(nil)
    assert_equal [], RoundtripJoinableArray.from_array(nil)
  end
  
  def test_to_s_should_be_uniq_and_compact
    assert_equal '1', RoundtripJoinableArray.from_array([nil, '1', '1']).to_s
  end
  
end
