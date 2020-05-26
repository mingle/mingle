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

class DateExtTest < ActiveSupport::TestCase
  
  def setup
    Clock.fake_now(:year => 2007, :month => 10, :day => 4)
  end    
  
  def teardown
    Clock.reset_fake
  end    

  def test_should_parse_ambiguous_date_to_preferred_format
    assert_equal "2007-01-02", Date.parse_with_hint("01/02/2007", "%m/%d/%Y").to_s
    assert_equal "2007-02-01", Date.parse_with_hint("01/02/2007", "%d/%m/%Y").to_s
    assert_equal "2007-02-01", Date.parse_with_hint("01/02/07", "%d/%m/%Y").to_s
    assert_equal "2007-01-02", Date.parse_with_hint("01/02/07", "%m/%d/%Y").to_s
    assert_equal "2001-02-07", Date.parse_with_hint("01/02/07", "%Y/%m/%d").to_s
    assert_equal "2007-02-01", Date.parse_with_hint("01 feb 07", "%d %b %Y").to_s
    assert_equal "2007-02-01", Date.parse_with_hint("01/02/07", "%d %b %Y").to_s
  end

  def test_should_parse_unambiguous_date_to_correct_format_ignoring_preferred_format
    assert_equal "2007-01-30", Date.parse_with_hint("30/01/2007", "%m/%d/%Y").to_s
    assert_equal "2007-01-30", Date.parse_with_hint("30/01/07", "%m/%d/%Y").to_s
    assert_equal "2007-01-30", Date.parse_with_hint("01-30-2007", "%d/%m/%Y").to_s
    assert_equal "2007-01-30", Date.parse_with_hint("01-30-2007", "%Y/%m/%d").to_s
    assert_equal "2007-01-30", Date.parse_with_hint("30-01-2007", "%Y/%m/%d").to_s
    assert_equal "2007-01-30", Date.parse_with_hint("30-01-2007", "%d %b %Y").to_s
    assert_equal "2007-01-30", Date.parse_with_hint("01-30-2007", "%d %b %Y").to_s
    assert_equal "2007-01-30", Date.parse_with_hint("30 jan 2007", "%d/%m/%Y").to_s
    assert_equal "2007-06-30", Date.parse_with_hint("jun 30, 2007", "%d/%m/%Y").to_s
  end

  def test_should_handle_non_zero_padded_dates
    assert_equal "2007-02-01", Date.parse_with_hint("1/2/7", "%d/%m/%Y").to_s
    assert_equal "2007-01-02", Date.parse_with_hint("1/2/7", "%m/%d/%Y").to_s
    assert_equal "2001-02-07", Date.parse_with_hint("1/2/7", "%Y/%m/%d").to_s
    assert_equal "2007-02-01", Date.parse_with_hint("1 feb 7", "%d %b %Y").to_s
  end

  def test_should_be_lenient_about_separators_handling_dashes_and_spaces
    assert_equal "2007-01-02", Date.parse_with_hint("01-02-2007", "%m/%d/%Y").to_s
    assert_equal "2007-02-01", Date.parse_with_hint("01 02 2007", "%d/%m/%Y").to_s
    assert_equal "2007-02-01", Date.parse_with_hint("1-feb-2007", "%d %b %Y").to_s
  end

  def test_should_parse_different_formats_defaulting_to_current_year
    y = Clock.now.year
    assert_equal "#{y}-02-01", Date.parse_with_hint("1/2", "%d/%m/%Y").to_s
    assert_equal "#{y}-01-02", Date.parse_with_hint("1/2", "%m/%d/%Y").to_s
    assert_equal "#{y}-01-02", Date.parse_with_hint("1/2", "%Y/%m/%d").to_s
    assert_equal "#{y}-01-31", Date.parse_with_hint("1/31", "%d/%m/%Y").to_s
    assert_equal "#{y}-01-31", Date.parse_with_hint("31/1", "%m/%d/%Y").to_s
    assert_equal "#{y}-01-31", Date.parse_with_hint("1/31", "%Y/%m/%d").to_s
    assert_equal "#{y}-01-30", Date.parse_with_hint("30 jan", "%d %b %Y").to_s
    assert_equal "#{y}-01-30", Date.parse_with_hint("30 jan", "%d/%m/%Y").to_s
    assert_equal "#{y}-06-30", Date.parse_with_hint("30 jun", "%d/%m/%Y").to_s
    assert_equal "#{y}-06-30", Date.parse_with_hint("30,jun", "%d/%m/%Y").to_s
    assert_equal "#{y}-01-30", Date.parse_with_hint("jan 30", "%d %b %Y").to_s
    assert_equal "#{y}-01-30", Date.parse_with_hint("30 january", "%d/%m/%Y").to_s
  end

  def test_should_handle_2_digit_years
    assert_equal "2006-01-30", Date.parse_with_hint("30 jan 06", "%d/%m/%Y").to_s
    assert_equal "1969-01-30", Date.parse_with_hint("30 jan 69", "%d/%m/%Y").to_s
    assert_equal "2068-01-30", Date.parse_with_hint("30 jan 68", "%d/%m/%Y").to_s
    assert_equal "1969-01-30", Date.parse_with_hint("30/1/69", "%d/%m/%Y").to_s
    assert_equal "2068-01-30", Date.parse_with_hint("30/1/68", "%d/%m/%Y").to_s
  end
  
  def test_should_still_parse_date_if_patten_is_not_recoganized_but_still_valid
    assert_equal "1969-08-25", Date.parse_with_hint("69 Aug 25", "%y %b %d").to_s
  end

  def test_gsub_date_should_recognize_date
    string, dates = gsub_date("start on 1969-01-30, and end at 2068-01-30", '%Y %m %d')
    assert_equal 'start on replaced, and end at replaced', string
    assert_equal ['1969-01-30', '2068-01-30'], dates
  end
    
  def test_pattern_for_format
    assert_match Date.pattern_for_format("%d/%m/%Y".dashed), "30 jan 06"
    assert_match Date.pattern_for_format("%d %b %Y".dashed), "1 Feb 2007"
    # assert !(Date.pattern_for_format("%d %b %Y".dasherize) =~ '1 Feb')
    # assert_match Date.pattern_for_format("%d %b %Y".dasherize, false), '1 Feb'
  end
    
  def test_string_should_not_be_modified_when_gsubing_a_not_parsable_date
    string, dates = gsub_date("start on 1969-02-30", '%Y %m %d')
    assert_equal "start on 1969-02-30", string
    assert dates.empty?
  end
  
  def test_gsub_with_more_format
    string, dates = gsub_date("start on 30 jan 69", '%d %m %Y')
    assert_equal 'start on replaced', string
    assert_equal ['1969-01-30'], dates
  end
  
  def test_should_throw_error_on_bad_dates
    bad_dates = ["", "   ", "x", "3/x/2007", "7sdf", "0", "0/0/0", "31/2/68", "11/2007", "324761412", "29:05:05"] # "1/2/20sd""jan12007", 
    bad_dates.each do |bad_date|
      assert_bad_date bad_date, "%d/%m/%Y"
      assert_bad_date bad_date, "%m/%d/%Y"
      assert_bad_date bad_date, "%Y/%m/%d"
      assert_bad_date bad_date, "%d %b %Y"
    end
    assert_bad_date "31/1", "%Y/%m/%d"
  end

  def assert_bad_date(date, format)
    assert_raise(ArgumentError) do
      str = Date.parse_with_hint(date, format).to_s
      puts "Bad date '#{date}' should cause error, but parsed to #{str} instead, format: #{format}!"
    end
  end
  
  def gsub_date(string, prefered_format)
    dates = []
    Date.gsub_date!(string, prefered_format) {|date| dates << date ; 'replaced'}
    return string, dates.collect(&:to_s)
  end


  def test_should_convert_date_into_epoch_milliseconds
    expected_epoch_milliseconds =  Date.parse('25-01-2018').to_time.to_i * 1000
    assert_equal  expected_epoch_milliseconds, Date.parse('25-01-2018').to_epoch_milliseconds
  end
end
