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

class CardViewLimitsTest < ActiveSupport::TestCase

  def test_allow_export_with_limit_enabled_returns_false_when_over_500
    assert_false CardViewLimits.allow_export?(501)
    assert CardViewLimits.allow_export?(500)
  end

  def test_allow_bulk_udpate_with_limit_enabled_returns_false_when_over_500
    assert_false CardViewLimits.allow_bulk_update?(501)
    assert CardViewLimits.allow_bulk_update?(500)
  end

end
