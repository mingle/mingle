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

class OldTextHelperTest < ActiveSupport::TestCase
  include ActionView::Helpers::TextHelper

  def test_should_not_turn_the_email_inside_a_mailto_href_into_a_link
      assert_equal '<p><a href="mailto:osito@bonito.com"&gt;email</a></p>', original_auto_link('<p><a href="mailto:osito@bonito.com"&gt;email</a></p>')
  end
  
  def test_should_not_turn_the_email_inside_a_mailto_href_into_a_link_when_link_text_is_the_email
      assert_equal '<p><a href="mailto:osito@bonito.com"&gt;osito@bonito.com</a></p>', original_auto_link('<p><a href="mailto:osito@bonito.com"&gt;osito@bonito.com</a></p>')
  end
    
  def test_should_turn_email_into_a_mailto_link
    assert_equal '<p><a href="mailto:osito@bonito.com">osito@bonito.com</a></p>', original_auto_link('<p>osito@bonito.com</p>')
  end
  
  def test_multiple_email_links_in_same_text
    original_content = <<-CONTENT
      <p><a href="mailto:billd@thoughtworks.com">Mail Bill</a></p>
      <p>billd@thoughtworks.com</p>
      <p><a href="mailto:billd@thoughtworks.com">billd@thoughtworks.com</a></p>
    CONTENT
    
    expected_content = <<-CONTENT
      <p><a href="mailto:billd@thoughtworks.com">Mail Bill</a></p>
      <p><a href="mailto:billd@thoughtworks.com">billd@thoughtworks.com</a></p>
      <p><a href="mailto:billd@thoughtworks.com">billd@thoughtworks.com</a></p>
    CONTENT
     
    assert_equal expected_content, original_auto_link(original_content)
  end
  
  def test_should_not_turn_the_email_inside_a_xmpp_href_into_a_link
      assert_equal '<p><a href="xmpp:osito@bonito.com"&gt;Chat</a></p>', original_auto_link('<p><a href="xmpp:osito@bonito.com"&gt;Chat</a></p>')
  end
  
  
end
