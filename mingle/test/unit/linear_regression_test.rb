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

require "linear_regression"

class LinearRegressionTest < Test::Unit::TestCase
  include LinearRegression

  def test_linear_f
    assert_equal({'w1' => 1, 'w0' => 0}, linear_f([0, 1, 2], [0, 1, 2]))
    assert_equal({'w1' => -1, 'w0' => 3}, linear_f([3, 6, 4, 5], [0, -3, -1, -2]))
    assert_equal({"w0"=>0.5, "w1"=>0.9}, linear_f([2, 4, 6, 8], [2, 5, 5, 8]))
  end
end
