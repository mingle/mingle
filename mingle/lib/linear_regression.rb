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

module LinearRegression
  # y = w1 * x + w0
  # x = (y - w0)/w1
  def linear_f(x, y)
    raise "x.size != y.size" if x.size != y.size
    m = x.size
    sigma_xy = sigma([x,y].transpose.collect{|xi,yi| xi*yi})
    sigma_x2 = sigma(x.collect{|xi| xi * xi})
    sigma_x = sigma(x)
    sigma_y = sigma(y)

    w1 = (m * sigma_xy - sigma_x * sigma_y).to_f / (m * sigma_x2 - sigma_x * sigma_x)
    w0 = (sigma_y - w1 * sigma_x).to_f / m
    
    {'w0' => w0, 'w1' => w1}
  end

  def sigma(array)
    array.reduce(0) {|sum, a| sum += a}
  end

  extend self
end
