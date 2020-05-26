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

class TextHelperExtensionTest < ActiveSupport::TestCase
  
  include ActionView::Helpers::TextHelper
  
  def test_humanize_join
    assert_equal 'apple', humanize_join(['apple'])
    assert_equal 'apple and orange', humanize_join(['apple', 'orange'])
    assert_equal 'apple, orange and peach', humanize_join(['apple', 'orange', 'peach'])
    assert_equal 'apple, orange and peach', humanize_join(['apple', nil, 'orange', '', 'peach'])
    assert_equal 'apple or orange', humanize_join(['apple', 'orange'], "or")
    assert_equal 'apple, orange or peach', humanize_join(['apple', 'orange', 'peach'], 'or')
  end
  
  def test_pluralize_exists
    assert_equal '1 apple', pluralize_exists(1, 'apple')
    assert_nil pluralize_exists(0, 'apple')
    assert_nil pluralize_exists(-1, 'apple')
  end
  
end
