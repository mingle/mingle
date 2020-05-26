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


class LineTest < ActiveSupport::TestCase

  def test_should_return_intersection_point
    line = Charts::Forecastable::Line.new([30.0, 10.0], [50.0, 20.0])
    assert_equal 12.5, line.y(35.0)
  end
  
  def test_slope
    line = Charts::Forecastable::Line.new([30.0, 10.0], [50.0, 20.0])
    assert_equal 0.5, line.slope

    line = Charts::Forecastable::Line.new([20.0, 20.0], [30.0, 20.0])
    assert_equal 0, line.slope
  end

  def test_return_slope_only_when_start_end_have_different_x_coordinates
    line = Charts::Forecastable::Line.new([30.0, 10.0], [30.0, 20.0])
    assert_nil line.slope
  end

  def test_should_return_intercept
    line = Charts::Forecastable::Line.new([30.0, 10.0], [50.0, 20.0])
    assert_equal -5.0, line.intercept
  end
  
  def test_should_return_nil_for_point
    line = Charts::Forecastable::Line.new([50.0, 20.0], [50.0, 20.0])
    assert_nil line.y(35.0)
  end
    

end
