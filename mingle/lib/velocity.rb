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

require 'linear_regression'

class Velocity

  attr_reader :data, :x_axis

  def initialize(data, x_axis=nil)
    @data = data
    @x_axis = x_axis || (0..(@data.size-1)).to_a
  end

  def invalid?
    zero? || negative? || nan?
  end

  def nan?
    linear_f['w1'].nan?
  end

  def zero?
    linear_f['w1'] == 0
  end
  
  def negative?
    linear_f['w1'] < 0
  end

  def rate_f
    # y = w1 * x + w0
    # x = (y - w0)/w1
    f = linear_f
    lambda do |y|
      # w1 is the slope, or velocity
      y/f['w1']
    end
  end

  # {'w0' => w0, 'w1' => w1}
  def linear_f
    LinearRegression.linear_f(@x_axis, completion_values)
  end

  def time_to_reach(distance)
    rate_f.call(distance)
  end

  def completion_values
    @data
  end

  def forecast(scope_values, scope_multiplier)
    scope_value = scope_values.last
    completion_value = completion_values.last
    unfinished_scope = (scope_value - completion_value) * scope_multiplier

    end_scope = completion_value + unfinished_scope

    log("current scope: #{scope_value}")
    log("unfinished scope (risk multiplier (#{scope_multiplier}) applied): #{unfinished_scope} = (current scope - completed scope (#{completion_value})) * risk multiplier")
    log("end scope: #{end_scope} = completed scope(#{completion_value}) + unfinished scope(#{unfinished_scope})")
    log("days to complete all the scope by completion trend: #{time_to_reach(end_scope)}")
    log("days to complete the unfinished scope by completion velocity slope: #{time_to_reach(unfinished_scope)}")
    [time_to_reach(unfinished_scope), end_scope, completion_value]
  end

  def log(msg)
    if defined?(Kernel.logger)
      Kernel.logger.info("[DAILY HISTORY CHART FORECAST] #{msg}")
    end
  end

  def ==(obj)
    completion_values == obj.completion_values && x_axis == obj.x_axis
  end

  def hash
    @data.hash * 13 + x_axis.hash
  end
end
