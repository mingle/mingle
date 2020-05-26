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

class JsStripperTest < Test::Unit::TestCase
  def test_should_be_able_to_strip_all_script_tag
    content = "<b>Helloa</b><script>bad</script><b>Hellob</b><script>bad2</script><b>Helloc</b>"
    assert_equal "<b>Helloa</b><b>Hellob</b><b>Helloc</b>", JsStripper.new.strip(content)
  end
  
  def test_should_strip_all_event_handler
    content = '<a onclick="alert(\'!\')" title="candy"> a link  </a> <img scr="/1.gif" onload="alert(\'!\')" />'
    assert_equal '<a title="candy"> a link  </a> <img scr="/1.gif" />', JsStripper.new.strip(content)    
  end
end
