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

class ColorTest < ActiveSupport::TestCase

  def test_random_gives_random_css_rgb_value
    assert Color.valid?(Color.random)
  end

  def test_random_can_accept_already_used_values_to_not_return
    all_but_black = Color.defaults - ['#000000']
    assert_equal '#000000', Color.random(all_but_black)
  end

  def test_random_with_all_used_up_returns_nil
    assert_nil Color.random(Color.defaults)
  end

  def test_valid_checks_hex_format
    assert Color.valid?('#ABC123')
    assert_false Color.valid?('#G0AABB')
    assert_false Color.valid?(nil)
    assert_false Color.valid?('')
  end

  def test_for_returns_the_same_hash_for_the_same_string_everytime
    color_for_abc = Color.for("abc")
    3.times do
      assert_equal color_for_abc, Color.for("abc")
    end
  end
end
