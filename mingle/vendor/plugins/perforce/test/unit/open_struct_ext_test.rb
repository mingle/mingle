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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
class OpenStructExtTest < ActiveSupport::TestCase
  
  def test_parse_key_value_pair_string_splitted_by_space
    state = OpenStruct.new
    
    
    state.parse("hello lalala")
    assert_equal 'lalala', state.hello

    state.parse("hello")
    assert_equal nil, state.hello

    state.parse("hello something with multi  space")
    assert_equal "something with multi  space", state.hello
        
    state.parse("")
  
  end
end
