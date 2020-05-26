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

require File.dirname(__FILE__) + '/test_helper'   

class XPathSugarTest < Test::Unit::TestCase
  def test_should_return_correctly_formatted_xpaths
    assert_equal "//select[@name='hello']", select_with_name('hello') 
    assert_equal "//textarea[@id='something']", textarea_with_id('something')  
    assert_equal "//a[@name='baah' and @id='123']", link_with_name_and_id('baah','123')
  end

  def test_should_reject_non_html_elements 
    begin  
      pizza_with_name('fourcheeses')
      fail "Should have errored"
    rescue NoMethodError
    end
  end       
  
  def test_should_have_xpath_methods
    begin
      input_with_name('hello') 
    rescue NoMethodError
      fail "XPath methods should have been mixed-in to TestCase"
    end
  end
end
