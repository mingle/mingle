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

class Time
  def same_day?(expect_time = Clock.now)
    self.all_day == expect_time.all_day
  end
  
  def same_week?(expect_time = Clock.now)
    if expect_time > self
      expect_time.all_day - self.all_day + self.wday < 7
    else
      self.all_day - expect_time.all_day + expect_time.wday <7
    end
  end
  
  def all_day
    self.year * 366 + self.yday
  end
  
  def milliseconds
    self.to_f * 1000
  end
  
  def self.from_java_date(date)
    Time.at(date.time / 1000, (date.time % 1000) * 1000)
  end
  
  def tz_format
    self.strftime('%Y-%m-%dT%H:%M:%SZ')
  end
end
