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

require File.join(File.dirname(__FILE__), 'unit_test_helper')

class GoogleCalendarMacroTest < Test::Unit::TestCase
  
  def setup
    @src = 'http://www.google.com/calendar/embed?title=%20&amp&src=some_encrypted_code'
    @width = 400
    @height = 300
  end
  
  def test_macro_contents
    google_calendar_macro = GoogleCalendarMacro.new({
        'src' => @src,
        'width' => @width,
        'height' => @height },
      nil, nil)
    result = google_calendar_macro.execute
    assert result.include?('iframe')
    assert result.include?("src=\"#{@src}\"")
    assert result.include?("width=\"#{@width}\"")
    assert result.include?("height=\"#{@height}\"")
  end

  def test_source_that_looks_like_a_url
    @src = "http://www.google.com/calendar/embed?title=blabla&src=some_encrypted_code"
    
    google_calendar_macro = GoogleCalendarMacro.new({
        'src' => "<h3>DGSDGSDG</h3>"},
      nil, nil)
    begin
      result = google_calendar_macro.execute
    rescue =>  e
    assert e.message.include?('Parameter src must be a recognized Google Calendar URL.')
  end
  end

  
  def test_valid_source
    @src = "http://www.google.com/calendar/embed?title=blabla&src=some_encrypted_code"
    
    google_calendar_macro = GoogleCalendarMacro.new({
        'src' => @src,
        'width' => @width,
        'height' => @height },
      nil, nil)
    result = google_calendar_macro.execute
    
    assert result.include?('iframe')
    assert result.include?("src=\"#{@src}\"")
    assert result.include?("width=\"#{@width}\"")
    assert result.include?("height=\"#{@height}\"")
    
    @src = "http://www.google.com/calendar/hello?src=some_encrypted_code"
    
    google_calendar_macro = GoogleCalendarMacro.new({
        'src' => @src,
        'width' => @width,
        'height' => @height },
      nil, nil)
    result = google_calendar_macro.execute
    
    assert result.include?('iframe')
    assert result.include?("src=\"#{@src}\"")
    assert result.include?("width=\"#{@width}\"")
    assert result.include?("height=\"#{@height}\"")
  end
  
  def test_should_provide_error_message_if_source_is_invalid
    @src = 'blabla'
    
    google_calendar_macro = GoogleCalendarMacro.new({
        'src' => @src,
        'width' => @width,
        'height' => @height },
      nil, nil)
    begin
      google_calendar_macro.execute
    rescue => e
      assert e.message.include?('Parameter src must be a recognized Google Calendar URL.')
    end
    
    @src = 'http://www.google.com/calendarblabla'
    
    google_calendar_macro = GoogleCalendarMacro.new({
        'src' => @src,
        'width' => @width,
        'height' => @height },
      nil, nil)
      begin
        google_calendar_macro.execute
      rescue => e
        assert e.message.include?('Parameter src must be a recognized Google Calendar URL.')    
      end
    #Bug #9202
    @src = 'abchttp://www.google.com/calendar/hello?src=some_encrypted_code'
    
    google_calendar_macro = GoogleCalendarMacro.new({
        'src' => @src,
        'width' => @width,
        'height' => @height },
      nil, nil)
      begin
        google_calendar_macro.execute
      rescue => e
        assert e.message.include?('Parameter src must be a recognized Google Calendar URL.')
    end
  end
end
