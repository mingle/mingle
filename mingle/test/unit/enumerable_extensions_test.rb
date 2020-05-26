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

class EnumerableExtensionsTest < ActiveSupport::TestCase

  def test_group_by_with_default
    values = 1..10
    actual = values.group_by_with_default([]) { |e| e % 2 == 0 }
    assert_equal [2, 4, 6, 8, 10], actual[true]
    assert_equal [1, 3, 5, 7, 9], actual[false]
    assert_equal [], actual['NOT EXIST']
    actual['NOT EXIST'] << 'a'
    assert_equal [], actual['also not exist']
  end

end
