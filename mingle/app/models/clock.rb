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

class Clock
  UTC_TIMEZONE = ActiveSupport::TimeZone.new(0)
  
  def self.now
    Time.now.utc
  end
  
  def self.today(timezone=UTC_TIMEZONE)
    right_now = timezone.utc_to_local Clock.now
    Date.new(right_now.year, right_now.month, right_now.day)
  end

  def self.yesterday
    self.today - 1
  end  

  def self.tomorrow
    self.today.next
  end  
  
  def self.last_monday
    return today.wday == 0 ? today - 6 : today - today.wday + 1
  end  

  def self.two_mondays_ago
    return last_monday - 7
  end  

  def self.next_monday
    last_monday + 7
  end 
  
  def self.first_of_next_month
    result = today
    result += 1 while (result.mday >= 1 && result.month == today.month)
    return result 
  end   

  def self.first_of_the_month
    today - today.mday + 1
  end  
  
  def self.client_timezone_offset
    nil
  end
end
