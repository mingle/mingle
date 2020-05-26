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

class TableSequenceTest < ActiveSupport::TestCase

  def setup
    @seq = TableSequence.find_or_create_by(name: 'block')
  end

  def test_next_will_update_current
    assert_equal 0, @seq.current
    assert_equal 1, @seq.next
    assert_equal 1, @seq.current
  end

  def test_reserve_will_update_current
    @seq.reserve(10)
    assert_equal 10, @seq.current
  end

  def test_reserve_should_return_first_reserved
    assert_equal 1, @seq.reserve(10)
  end

  def test_reset_to
    @seq.reset_to(1000)
    assert_equal 1000, @seq.current
    @seq.reset_to(100)
    assert_equal 100, @seq.current
  end

end
