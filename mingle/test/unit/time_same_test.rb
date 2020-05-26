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

class TimeSameTest < ActiveSupport::TestCase
  
  def test_same_day
    time_4_3_1 =  Time.gm(2007,"apr",3,1)
    time_4_3_23 = Time.gm(2007,"apr",3,23)
    time_4_4_1 =  Time.gm(2007,"apr",2,1)
    
    assert time_4_3_1.same_day?(time_4_3_23)
    assert time_4_3_23.same_day?(time_4_3_1)
    assert !time_4_3_1.same_day?(time_4_4_1)
  end
  
  def test_same_week
    time_4_1 =  Time.gm(2007,"apr",1) #sunday
    time_4_2 =  Time.gm(2007,"apr",2) #tuesday
    time_4_7 =  Time.gm(2007,"apr",7) #saturday
    time_4_8 =  Time.gm(2007,"apr",8) #next saturday
    
    assert time_4_1.same_week?(time_4_2)
    assert time_4_1.same_week?(time_4_7)
    assert !time_4_1.same_week?(time_4_8)
    
    assert time_4_7.same_week?(time_4_2)
    assert time_4_7.same_week?(time_4_1)
    assert !time_4_8.same_week?(time_4_7)
  end
  
end
