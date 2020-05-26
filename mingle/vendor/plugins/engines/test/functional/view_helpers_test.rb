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

require File.dirname(__FILE__) + '/../test_helper'

class ViewHelpersTest < ActionController::TestCase
  tests AssetsController
  
  def setup
    get :index
  end
  
  def test_plugin_javascript_helpers
    base_selector = "script[type='text/javascript']"
    js_dir = "/plugin_assets/test_assets/javascripts"
    assert_select "#{base_selector}[src='#{js_dir}/file.1.js']"
    assert_select "#{base_selector}[src='#{js_dir}/file2.js']"
  end

  def test_plugin_stylesheet_helpers
    base_selector = "link[media='screen'][rel='stylesheet'][type='text/css']"
    css_dir = "/plugin_assets/test_assets/stylesheets"
    assert_select "#{base_selector}[href='#{css_dir}/file.1.css']"
    assert_select "#{base_selector}[href='#{css_dir}/file2.css']"
  end

  def test_plugin_image_helpers
    assert_select "img[src='/plugin_assets/test_assets/images/image.png'][alt='Image']"
  end

  def test_plugin_layouts
    get :index
    assert_select "div[id='assets_layout']"
  end  

  def test_plugin_image_submit_helpers
    assert_select "input[src='/plugin_assets/test_assets/images/image.png'][type='image']"
  end

end
