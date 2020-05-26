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

class ClockTest < ActiveSupport::TestCase
  
  def setup
    #faked out to stay at 17th December, 2006 - a sunday
    Clock.fake_now(:year => 2006, :month => 12, :day => 17)
  end
  
  def teardown
    Clock.reset_fake
  end
  
  def test_should_know_yesterday
    assert_equal Date.new(2006, 12, 16), Clock.yesterday
  end  
  
  def test_should_know_tomorrow
    assert_equal Date.new(2006, 12, 18), Clock.tomorrow
  end  
  
  def test_should_know_last_monday_on_a_sunday_as_the_mondat
    assert_equal Date.new(2006, 12, 11), Clock.last_monday
  end  
  
  def test_should_know_last_monday_on_a_tuesday_as_the_day_that_just_elapsed
    Clock.fake_now(:year => 2006, :month => 12, :day => 19)
    assert_equal Date.new(2006, 12, 18), Clock.last_monday
  end  
  
  def test_should_know_first_of_month
    assert_equal Date.new(2006, 12, 1), Clock.first_of_the_month
  end  
  
  def test_should_know_last_day_of_month_during_long_month
    assert_equal Date.new(2007, 1, 1), Clock.first_of_next_month
  end  
  
  def test_should_know_last_day_of_month_during_short_month
    Clock.fake_now(:year => 2006, :month => 11, :day => 17)
    assert_equal Date.new(2006, 12, 1), Clock.first_of_next_month
  end  
  
  def test_should_know_last_day_of_month_during_very_short_month
    Clock.fake_now(:year => 2006, :month => 2, :day => 17)
    assert_equal Date.new(2006, 3, 1), Clock.first_of_next_month
  end  
  
  def test_should_know_last_day_of_month_during_leap_month
    Clock.fake_now(:year => 2008, :month => 2, :day => 17)    
    assert_equal Date.new(2008, 3, 1).strftime, Clock.first_of_next_month.strftime
  end

  def test_should_caculate_today_according_to_timezone_if_specified
    Clock.fake_now(:year => 2008, :month => 2, :day => 17) # utc time
    assert_equal Date.new(2008, 2, 16).strftime, Clock.today(ActiveSupport::TimeZone.new('Central America')).strftime
    assert_equal Date.new(2008, 2, 17).strftime, Clock.today(ActiveSupport::TimeZone.new('Sydney')).strftime
  end
end  
