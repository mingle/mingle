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

require 'rubygems'
require File.join(File.dirname(__FILE__), 'unit_test_helper')

class GoogleMapsMacroTest < Test::Unit::TestCase
  
  def setup
    @src = 'http://maps.google.com/maps?f=q&geocode=&hl=en&ie=UTF8&ll=48.825121%2C2.198518&output=embed&q=48.825183%2C2.1985795&sll=37.0625%2C-95.677068&source=s_q&spn=0.00072%2C0.001528&sspn=55.981213%2C100.107422&t=h&z=20'
    @width = 400
    @height = 300
  end
  
  def test_macro_contents
    google_maps_macro = GoogleMapsMacro.new({
        'src' => @src,
        'width' => @width,
        'height' => @height },
      nil, nil)
    result = google_maps_macro.execute
    assert result.include?('iframe')
    assert result.include?("src=\"#{@src}\"")
    assert result.include?("width=\"#{@width}\"")
    assert result.include?("height=\"#{@height}\"")
  end
  
  def test_should_give_nice_error_if_src_parameter_is_not_provided
    google_maps_macro = GoogleMapsMacro.new({
        'width' => @width,
        'height' => @height },
      nil, nil)
      begin
        google_maps_macro.execute
      rescue => e
        assert e.message.include?('Parameter src must be a recognized Google Maps URL.')
      end
  end

  def test_should_give_nice_error_if_invalid_src_parameter
    google_maps_macro = GoogleMapsMacro.new({
        'width' => @width,
        'height' => @height ,
        'src' => 'http://www.bobsmapservice.com/'},
      nil, nil)
    begin
      google_maps_macro.execute
    rescue => e
      assert e.message.include?('Parameter src must be a recognized Google Maps URL.')
    end
  end
  
  def test_should_give_nice_error_if_src_does_not_have_a_host
    google_maps_macro = GoogleMapsMacro.new({
        'width' => @width,
        'height' => @height ,
        'src' => 'http:///blah'},
      nil, nil)
      begin
        google_maps_macro.execute
      rescue => e
        assert e.message.include?('Parameter src must be a recognized Google Maps URL.')
      end
  end

  def test_should_append_output_embed_if_not_given
    google_maps_macro = GoogleMapsMacro.new({
        'src' => 'http://maps.google.com/'},
      nil, nil)
    result = google_maps_macro.execute
    assert result.include?('src="http://maps.google.com/?output=embed"')
  end
  
  def test_should_return_a_friendly_error_if_you_give_a_url_of_html
    google_maps_macro = GoogleMapsMacro.new({
        'src' => '<h3>dsfasfasfdfsf</h3>'},
      nil, nil)
      begin
        google_maps_macro.execute
      rescue => e
        assert e.message.include?('Parameter src must be a recognized Google Maps URL.')
      end
  end
  
  def test_should_not_render_with_a_url_that_does_not_start_with_http_or_https
    google_maps_macro = GoogleMapsMacro.new({
        'src' => 'zhttp://maps.google.com/'},
      nil, nil)
      begin
        google_maps_macro.execute
      rescue => e
        assert e.message.include?('Parameter src must be a recognized Google Maps URL.')
      end
  end

  def test_should_rewrite_output_if_we_provide_it
    google_maps_macro = GoogleMapsMacro.new({
        'src' => 'http://maps.google.com/?output=norlan'},
      nil, nil)
    result = google_maps_macro.execute
    assert result.include?('src="http://maps.google.com/?output=embed"')
  end

end
