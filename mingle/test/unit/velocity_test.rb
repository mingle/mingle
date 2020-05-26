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
require 'date'
require "velocity"

class VelocityTest < Test::Unit::TestCase
  def test_should_forecast_based_on_rate
    velocity = Velocity.new([0, 1, 2, 3])
    assert_equal 3, velocity.time_to_reach(3)
    velocity = Velocity.new([0, 1.5])
    assert_equal 2, velocity.time_to_reach(3)
  end

  def test_should_not_round_result_of_time_to_reach
    velocity = Velocity.new([0, 1.5])
    assert_in_delta 1.33, velocity.time_to_reach(2), 0.01
  end

  def test_equal
    assert_equal Velocity.new([0, 1.5]), Velocity.new([0, 1.5])
    assert_equal Velocity.new([0, 1.5]).hash, Velocity.new([0, 1.5]).hash

    assert_not_equal Velocity.new([0, 1.5], [1, 2]), Velocity.new([0, 1.5], [1, 3])
    assert_not_equal Velocity.new([0, 1.5], [1, 2]).hash, Velocity.new([0, 1.5], [1, 3]).hash
  end

  def test_forecast_returns_scope_and_completed_and_forecasted_date
    velocity = Velocity.new([0, 0, 1, 1, 2, 2])
    time_to_reach, end_scope, completed = velocity.forecast([3, 3, 5, 5, 5, 5], 1.5)
    assert_equal 6.5, end_scope
    assert_equal velocity.time_to_reach(6.5 - 2), time_to_reach
    assert_equal 2, completed
  end

  def test_valid_velocity
    velocity = Velocity.new([0, 1])
    assert !velocity.invalid?
  end

  def test_no_velocity
    velocity = Velocity.new([0, 0])
    assert velocity.zero?
    assert velocity.invalid?

    velocity = Velocity.new([10, 10])
    assert velocity.zero?
    assert velocity.invalid?
  end
  
  def test_negative_velocity
    velocity = Velocity.new([2, 1])
    assert velocity.negative?
    assert velocity.invalid?
  end

  def test_nan_velocity
    velocity = Velocity.new([2, 2], [1, 1])
    assert velocity.nan?
    assert velocity.invalid?
  end

  def test_calculate_velocity_for_data_points_with_x_axis_values
    completion = [0, 0, 1, 1, 2, 2]
    x_axis = [0, 1, 2, 3, 4, 5]
    velocity = Velocity.new(completion, x_axis)
    assert_in_delta 9.84, velocity.time_to_reach(4.5), 0.01
  end

  def test_calculate_velocity_for_data_points_with_unequal_interval
    completion = [0, 0, 1, 1, 2, 2]
    x_axis = [123, 125, 222, 234, 344, 500]
    velocity = Velocity.new(completion, x_axis)
    assert_in_delta 783.32, velocity.time_to_reach(4.5), 0.01
  end

  def between(date1, date2)
    (Date.parse(date2) - Date.parse(date1)).to_i
  end
end
